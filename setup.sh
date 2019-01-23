#!/bin/sh
echo "Forcing IP as 192.168.99.100 by deleting HostInterfaceNetworking-vboxnet0*"
rm ~/.config/VirtualBox/HostInterfaceNetworking-vboxnet0*

# Create certificates
# rm -rf ./certs
./certs.sh 192.168.99.100

# Copy certificates

mkdir -p ~/.minikube/certs
cp -f ./certs/minikube-self-ca.crt ~/.minikube/certs/ca.pem
cp -f ./certs/minikube-self-ca.key ~/.minikube/certs/ca-key.pem
cp -f ./certs/minikube-self-ca.crt ~/.minikube/ca.crt
cp -f ./certs/minikube-self-ca.key ~/.minikube/ca.key

# Start minikube
minikube start --memory 8192 --cpus 4 --iso-url ./minikube.iso
minikube addons enable ingress
minikube addons enable dashboard
minikube addons enable heapster

# Setup helm
helm init
kubectl rollout status deployment/tiller-deploy -n kube-system

# Store secret in kubernetes
kubectl create secret tls wildcard-testing-selfsigned-tls --cert=./certs/192.168.99.100-nip.fullchain.crt --key=./certs/192.168.99.100-nip.key

# Add gitlab repo
helm repo add gitlab https://charts.gitlab.io/
helm repo update

# Install gitlab using helm
# Use CE version
helm upgrade --install gitlab gitlab/gitlab -f ./gitlab/values-minikube.yaml --set gitlab.migrations.image.repository=registry.gitlab.com/gitlab-org/build/cng/gitlab-rails-ce --set gitlab.sidekiq.image.repository=registry.gitlab.com/gitlab-org/build/cng/gitlab-sidekiq-ce --set gitlab.unicorn.image.repository=registry.gitlab.com/gitlab-org/build/cng/gitlab-unicorn-ce --set gitlab.unicorn.workhorse.image=registry.gitlab.com/gitlab-org/build/cng/gitlab-workhorse-ce --set gitlab.task-runner.image.repository=registry.gitlab.com/gitlab-org/build/cng/gitlab-task-runner-ce

# Wait for gitlab rollout to finish
kubectl rollout status deployment/tiller-deploy -n kube-system

# Create dashboard ingress
kubectl -f dashboard-ingress.yaml

# Print gitlab root password
echo "\nGitlab info:"
echo "Root password: $(kubectl get secret gitlab-gitlab-initial-root-password -ojsonpath={.data.password} | base64 --decode ; echo)"
echo "URL: https://gitlab.192.168.99.100.nip.io\n"

echo "Minikube:"
echo "Dashboard: https://dashboard.192.168.99.100.nip.io"
echo "IP: $(minikube ip)"

# echo "URL: https://minio.192.168.99.100.nip.io"

# All good?

echo "\nRemember to install the CA certs where needed (likely on your devel computer)"
