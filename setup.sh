#!/bin/sh
set -e
# Delete certs
# rm -rf ./certs

# Create CA certificates
./certs_ca.sh

# Copy CA certificates
mkdir -p ~/.minikube/certs
cp -f ./certs/kubernetes-dev-self-ca.crt ~/.minikube/certs/ca.pem
cp -f ./certs/kubernetes-dev-self-ca.key ~/.minikube/certs/ca-key.pem
cp -f ./certs/kubernetes-dev-self-ca.crt ~/.minikube/ca.crt
cp -f ./certs/kubernetes-dev-self-ca.key ~/.minikube/ca.key
mkdir -p ~/.minikube/files/etc/ssl/certs/

# Remove nginx ssl ingress addon if using traefik
if [ -z "$NGINXINGRESS" ]
then
echo "Traefik Ingress used, will remove nginx ingress ssl addon, if previously installed"
rm -rf ~/.minikube/addons/ingress-ssl
fi

# Start minikube
# Check if minikube is running already
set +e
minikube status > /dev/null 2>&1
if [ $? -ne '0' ]; then
  set -e
  echo 'Starting up minikube (will create if not existing)'
  minikube start --driver=docker --memory 10240 --cpus 6 --disk-size 35g 
  # minikube start --memory 10240 --cpus 4 --disk-size 35g
fi

set -e
# Ensure minikube is running before going forward
echo "Minikube status:"
minikube status
echo "\n";
# Using own ingress (ingress-ssl)
# minikube addons disable ingress
minikube addons enable dashboard
minikube addons enable metrics-server
# minikube addons enable heapster
# minikube addons disable ingress
IP=$(minikube ip)

# Stop minikube
minikube stop
# Copy certs for docker engine
mkdir -p ~/.minikube/files/etc/docker/certs.d/registry.$IP.nip.io
# cp -f ./certs/kubernetes-dev-self-ca.crt ~/.minikube/files/etc/ssl/certs/registry.$IP.nip.io.crt
cp -f ./certs/kubernetes-dev-self-ca.crt ~/.minikube/files/etc/docker/certs.d/registry.$IP.nip.io/ca.crt

# Create other certificates
./certs.sh $IP
# cp -f ./certs/$IP-nip.crt ~/.minikube/files/etc/ssl/certs/registry.$IP.nip.io.pem

# Start minikube again with correct api-server-name to create correct certs for api
minikube start # --apiserver-name=kubeapi.$IP.nip.io

# Wait until system is ready again
kubectl rollout status deployment/kubernetes-dashboard -n kubernetes-dashboard
kubectl rollout status deployment/coredns -n kube-system

# Check if secret exists
set +e
kubectl get secret wildcard-testing-selfsigned-tls-$IP

if [ $? -ne '0' ]; then
  set -e
  # Store secret in kubernetes
  kubectl create secret tls wildcard-testing-selfsigned-tls-$IP --cert=./certs/$IP-nip.fullchain.crt --key=./certs/$IP-nip.key
  kubectl create secret tls wildcard-testing-selfsigned-tls-$IP --cert=./certs/$IP-nip.fullchain.crt --key=./certs/$IP-nip.key -n kube-system
  # For nginx ssl ingress
  kubectl create secret tls default-ssl-certificate --cert=./certs/$IP-nip.fullchain.crt --key=./certs/$IP-nip.key -n kube-system
else
  set -e
fi

set +e
kubectl get secret ca-testing-selfsigned-tls

if [ $? -ne '0' ]; then
  set -e
  # Store secret in kubernetes
  kubectl create secret generic ca-testing-selfsigned-tls --from-file=kubernetes-dev-self-ca.crt=./certs/kubernetes-dev-self-ca.crt
else
  set -e
fi

# If using traefik ingress, use helm chart with provided values.
if [ -z "$NGINXINGRESS" ]
then
echo "Installing traefik Ingress"
helm repo add traefik https://helm.traefik.io/traefik
helm repo update

# Read certificate and key and write as base64
BASE64SSLCERT=$(base64 ./certs/$IP-nip.fullchain.crt -w 0)
BASE64SSLPRIVATEKEY=$(base64 ./certs/$IP-nip.key -w 0)
sed "s/__IP__/$IP/g" traefik_values_template.yaml > traefik_values_t2.yaml
sed "s/__BASE64SSLCERT__/$BASE64SSLCERT/g" traefik_values_t2.yaml > traefik_values_t3.yaml
sed "s/__BASE64SSLPRIVATEKEY__/$BASE64SSLPRIVATEKEY/g" traefik_values_t3.yaml > traefik_values.yaml
rm -f traefik_values_t2.yaml
rm -f traefik_values_t3.yaml
# helm install traefik traefik/traefik

sed "s/__IP__/$IP/g" traefik_dashboard_template.yaml > traefik_dashboard.yaml

helm upgrade --install --values ./traefik_values.yaml traefik traefik/traefik --namespace kube-system
kubectl rollout status deployment/traefik --namespace kube-system
kubectl apply -f traefik_dashboard.yaml
else
# If using nginx-ingress with ssl, do this:
mkdir -p ~/.minikube/addons/ingress-ssl
sed "s/__IP__/$IP/g" ./ingress/ingress-ssl-dp_template.yaml > ./ingress/ingress-ssl-dp.yaml
cp -f ./ingress/*.yaml ~/.minikube/addons/ingress-ssl/
kubectl rollout status deployment/nginx-ingress-controller --namespace kube-system
fi

# Don't require auth for settings on dashboard
kubectl patch deployment kubernetes-dashboard -n kubernetes-dashboard  --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args", "value": [--disable-settings-authorizer]}]'

# List 30 items per page on dashboard as default
kubectl apply -f dashboard-settings.yaml -n kubernetes-dashboard
# Replace __IP__ in dashboard-ingress_template.yaml
# Create dashboard ingress
if [ -z "$NGINXINGRESS" ]
then
sed "s/__IP__/$IP/g" dashboard-ingress_traefik_template.yaml | kubectl apply -n kube-system -f -
else
sed "s/__IP__/$IP/g" dashboard-ingress_template.yaml | kubectl apply -n kube-system -f -
fi

# Install mailhog for e-mails from gitlab
sed "s/__IP__/$IP/g" mailhog_values_template.yaml > mailhog_values.yaml
helm upgrade --install --values ./mailhog_values.yaml mailhog stable/mailhog

# Add gitlab repo
helm repo add gitlab https://charts.gitlab.io/
helm repo update

# Replace __IP__ in gitlab/values-minikube_template.yaml
sed "s/__IP__/$IP/g" ./gitlab/values-minikube_template.yaml > ./gitlab/values-minikube.yaml

kubectl create secret generic gitlab-gitlab-initial-root-password --from-literal=password=$(echo kubedevelop | head -c 11)

# Install gitlab using helm
# Use CE version
helm upgrade --install gitlab gitlab/gitlab --values ./gitlab/values-minikube.yaml --set gitlab.migrations.image.repository=registry.gitlab.com/gitlab-org/build/cng/gitlab-rails-ce --set gitlab.sidekiq.image.repository=registry.gitlab.com/gitlab-org/build/cng/gitlab-sidekiq-ce --set gitlab.unicorn.image.repository=registry.gitlab.com/gitlab-org/build/cng/gitlab-unicorn-ce --set gitlab.unicorn.workhorse.image=registry.gitlab.com/gitlab-org/build/cng/gitlab-workhorse-ce --set gitlab.task-runner.image.repository=registry.gitlab.com/gitlab-org/build/cng/gitlab-task-runner-ce

# Wait for gitlab rollout to finish
kubectl rollout status deployment/gitlab-postgresql
kubectl rollout status deployment/gitlab-minio
kubectl rollout status deployment/gitlab-registry
kubectl rollout status deployment/gitlab-redis
kubectl rollout status deployment/gitlab-gitlab-shell
kubectl rollout status deployment/gitlab-sidekiq-all-in-1
kubectl rollout status deployment/gitlab-unicorn
# Remove ngnix class + provider requirements for gitlab, as we are running traefik
if [ -z "$NGINXINGRESS" ]
then
kubectl patch ingress gitlab-registry --type='json' -p='[{"op": "remove", "path": "/metadata/annotations"}]'
kubectl patch ingress gitlab-minio --type='json' -p='[{"op": "remove", "path": "/metadata/annotations"}]'
kubectl patch ingress gitlab-unicorn --type='json' -p='[{"op": "remove", "path": "/metadata/annotations"}]'
fi

# Check that runner successfully registers, after patching unicorn, minio and registry
kubectl rollout status deployment/gitlab-gitlab-runner

# Create postgres external access
sed "s/__IP__/$IP/g" gitlab/gitlab-postgres-external_template.yaml | kubectl create -f -

# Open shell on port 2222
sed "s/__IP__/$IP/g" gitlab/gitlab-shell-service-external-ip_template.yaml | kubectl create -f -

# Setup kubernetes service account for gitlab
./gitlab/setup_kube_account.sh

# Print gitlab info
./gitlab/gitlab_info.sh

# Print gitlab kubernetes integration info
./gitlab/setup_info.sh

echo "\nDomains for test apps:"
echo "   app1.$IP.nip.io"
echo "   app2.$IP.nip.io"
echo "   service1.$IP.nip.io"
echo "   service2.$IP.nip.io"

# echo "URL: https://minio.$IP.nip.io"

# All good?

echo "\nRemember to install the CA certs where needed (likely on your devel computer)"
echo "Also remember to set allow requests to local network in gitlab here: /admin/application_settings/network"
