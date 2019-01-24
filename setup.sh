#!/bin/sh
set -e
# echo "Forcing IP as 192.168.99.100 by deleting HostInterfaceNetworking-vboxnet0*"
# rm ~/.config/VirtualBox/HostInterfaceNetworking-vboxnet0*

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
minikube start --memory 8192 --cpus 4 --iso-url https://github.com/leifcr/minikube/releases/download/v0.33.1-iso-only/minikube-0.33.1-mac_fix.iso
minikube addons enable ingress
minikube addons enable dashboard
minikube addons enable heapster
IP=$(minikube ip)
# Create other certificates
./certs.sh $IP

# Setup helm
helm init
kubectl rollout status deployment/tiller-deploy -n kube-system

# Store secret in kubernetes
kubectl create secret tls wildcard-testing-selfsigned-tls --cert=./certs/$IP-nip.fullchain.crt --key=./certs/$IP-nip.key

# Add gitlab repo
helm repo add gitlab https://charts.gitlab.io/
helm repo update

# Replace __IP__ in gitlab/values-minikube_template.yaml
cp ./gitlab/values-minikube_template.yaml ./gitlab/values-minikube.yaml
sed -i "s/__IP__/$IP/g" ./gitlab/values-minikube.yaml

# Install gitlab using helm
# Use CE version
helm upgrade --install gitlab gitlab/gitlab -f ./gitlab/values-minikube.yaml --set gitlab.migrations.image.repository=registry.gitlab.com/gitlab-org/build/cng/gitlab-rails-ce --set gitlab.sidekiq.image.repository=registry.gitlab.com/gitlab-org/build/cng/gitlab-sidekiq-ce --set gitlab.unicorn.image.repository=registry.gitlab.com/gitlab-org/build/cng/gitlab-unicorn-ce --set gitlab.unicorn.workhorse.image=registry.gitlab.com/gitlab-org/build/cng/gitlab-workhorse-ce --set gitlab.task-runner.image.repository=registry.gitlab.com/gitlab-org/build/cng/gitlab-task-runner-ce

# Wait for gitlab rollout to finish
kubectl rollout status deployment/tiller-deploy -n kube-system

# Replace __IP__ in dashboard-ingress_template.yaml
cp dashboard-ingress_template.yaml dashboard-ingress.yaml
sed -i "s/__IP__/$IP/g" dashboard-ingress.yaml

# Create dashboard ingress
kubectl -f dashboard-ingress.yaml

# Print gitlab root password
echo "\nGitlab info:"
echo "Root password: $(kubectl get secret gitlab-gitlab-initial-root-password -ojsonpath={.data.password} | base64 --decode ; echo)"
echo "URL: https://gitlab.$IP.nip.io\n"

echo "Minikube:"
echo "Dashboard: https://dashboard.$IP.nip.io"
echo "IP: $(minikube ip)"

# echo "URL: https://minio.$IP.nip.io"

# All good?

echo "\nRemember to install the CA certs where needed (likely on your devel computer)"
