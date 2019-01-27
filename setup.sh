#!/bin/sh
set -e
# Delete certs
# rm -rf ./certs

# Create CA certificates
./certs_ca.sh

# Copy CA certificates
mkdir -p ~/.minikube/certs
cp -f ./certs/minikube-self-ca.crt ~/.minikube/certs/ca.pem
cp -f ./certs/minikube-self-ca.key ~/.minikube/certs/ca-key.pem
cp -f ./certs/minikube-self-ca.crt ~/.minikube/ca.crt
cp -f ./certs/minikube-self-ca.key ~/.minikube/ca.key

# Start minikube
# Check if minikube is running already
set +e
minikube status > /dev/null
if [ $? -ne '0' ]; then
  set -e
  minikube start --memory 8192 --cpus 4 --iso-url https://github.com/leifcr/minikube/releases/download/v0.33.1-iso-only/minikube-0.33.1-mac_fix.iso
fi

set -e
# Ensure minikube is running before going forward
echo "Minikube status:"
minikube status
echo "\n";
minikube addons enable ingress
minikube addons enable dashboard
minikube addons enable heapster
IP=$(minikube ip)

# Stop minikube
minikube stop
# Start minikube again with correct api-server-name to create correct certs for api
minikube start --apiserver-name=kubeapi.$IP.nip.io


# Create other certificates
./certs.sh $IP

# Setup helm
helm init
kubectl rollout status deployment/tiller-deploy -n kube-system

# Install mailhog for e-mails from gitlab
sed "s/__IP__/$IP/g" mailhog_values_template.yaml > mailhog_values.yaml
helm upgrade --install --values ./mailhog_values.yaml mailhog stable/mailhog

# Check if secret exists
set +e
kubectl get secret wildcard-testing-selfsigned-tls-$IP

if [ $? -ne '0' ]; then
  set -e
  # Store secret in kubernetes
  kubectl create secret tls wildcard-testing-selfsigned-tls-$IP --cert=./certs/$IP-nip.fullchain.crt --key=./certs/$IP-nip.key
  kubectl create secret tls wildcard-testing-selfsigned-tls-$IP --cert=./certs/$IP-nip.fullchain.crt --key=./certs/$IP-nip.key -n kube-system
else
  set -e
fi

set +e
kubectl get secret ca-testing-selfsigned-tls

if [ $? -ne '0' ]; then
  set -e
  # Store secret in kubernetes
  kubectl create secret generic ca-testing-selfsigned-tls --from-file=minikube-self-ca.crt=./certs/minikube-self-ca.crt
else
  set -e
fi

# Add gitlab repo
helm repo add gitlab https://charts.gitlab.io/
helm repo update

# Replace __IP__ in gitlab/values-minikube_template.yaml
sed "s/__IP__/$IP/g" ./gitlab/values-minikube_template.yaml > ./gitlab/values-minikube.yaml

kubectl create secret generic gitlab-gitlab-initial-root-password --from-literal=password=kubedevelop

# Install gitlab using helm
# Use CE version
helm upgrade --install gitlab gitlab/gitlab --values ./gitlab/values-minikube.yaml --set gitlab.migrations.image.repository=registry.gitlab.com/gitlab-org/build/cng/gitlab-rails-ce --set gitlab.sidekiq.image.repository=registry.gitlab.com/gitlab-org/build/cng/gitlab-sidekiq-ce --set gitlab.unicorn.image.repository=registry.gitlab.com/gitlab-org/build/cng/gitlab-unicorn-ce --set gitlab.unicorn.workhorse.image=registry.gitlab.com/gitlab-org/build/cng/gitlab-workhorse-ce --set gitlab.task-runner.image.repository=registry.gitlab.com/gitlab-org/build/cng/gitlab-task-runner-ce

# Wait for gitlab rollout to finish
kubectl rollout status deployment/tiller-deploy -n kube-system

# Don't require auth for settings on dashboard
kubectl patch deployment kubernetes-dashboard -n kube-system  --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args", "value": [--disable-settings-authorizer]}]'

# List 30 items per page on dashboard as default
kubectl apply -f dashboard-settings.yaml -n kube-system
# Replace __IP__ in dashboard-ingress_template.yaml
# Create dashboard ingress
sed "s/__IP__/$IP/g" dashboard-ingress_template.yaml | kubectl apply -n kube-system -f -

# Create postgres external access
sed "s/__IP__/$IP/g" gitlab/gitlab-postgres-external_template.yaml | kubectl create -f -

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
