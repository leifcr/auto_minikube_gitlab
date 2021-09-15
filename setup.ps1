# Initial params
Param($MINIKUBE_MEM=5000, $MINIKUBE_CPUS=4, $MINIKUBE_DISK='30g', $MINIKUBE_DRIVER='docker', $USENGINX='n')

# Delete certs?
$confirmation = Read-Host "Remove all certificates?"
if ($confirmation -eq 'y') {
  Remove-Item -LiteralPath ./certs -Force -Recurse
}

# Set config
Write-Output "Minikube config: Memory: $MINIKUBE_MEM CPUS $MINIKUBE_CPUS DISK: $MINIKUBE_DISK DRIVER: $MINIKUBE_DRIVER NGINX: $USENGINX"
$confirmation = Read-Host "Proceed with given configuration?"
if ($confirmation -ne 'y') {
  exit
}

# Update helm repos

# Add traefik
if ($USENGINX -ne 'y') {
  helm repo add traefik https://helm.traefik.io/traefik
}
# Add mailhog repo
helm repo add leifcr https://leifcr.github.io/helm-charts
# Add gitlab repo
helm repo add gitlab https://charts.gitlab.io/
helm repo update

# Create CA certificates
./certs_ca.ps1

# Copy CA certificates
mkdir ~/.minikube/certs -ea 0
Copy-Item ./certs/kubernetes-dev-self-ca.crt ~/.minikube/certs/ca.pem -Force
Copy-Item ./certs/kubernetes-dev-self-ca.key ~/.minikube/certs/ca-key.pem -Force
Copy-Item ./certs/kubernetes-dev-self-ca.crt ~/.minikube/ca.crt -Force
Copy-Item ./certs/kubernetes-dev-self-ca.key ~/.minikube/ca.key -Force
mkdir ~/.minikube/files/etc/ssl/certs/ -ea 0

if ($USENGINX -ne 'y') {
  # Traefik
  Write-Output "Traefik Ingress used, will remove nginx ingress ssl addon, if previously installed"
  Remove-Item -LiteralPath ~/.minikube/addons/ingress-ssl -Force -Recurse
}
# $IP=minikube ip
$IP='127.0.0.1'
Write-Output "IP: $IP"

# Create other certificates
try {
  ./certs.ps1 $IP
}
catch {
  Write-Output "Error creating certificates"
  exit
}

# Copy-Item ./certs/$IP-nip.crt ~/.minikube/files/etc/ssl/certs/registry.$IP.nip.io.pem -Force

# Copy certs for docker engine
mkdir ~/.minikube/files/etc/docker/certs.d/registry.$IP.nip.io -ea 0
# cp -f ./certs/kubernetes-dev-self-ca.crt ~/.minikube/files/etc/ssl/certs/registry.$IP.nip.io.crt
Copy-Item ./certs/kubernetes-dev-self-ca.crt ~/.minikube/files/etc/docker/certs.d/registry.$IP.nip.io/ca.crt -Force

# Start minikube
# Check if minikube is running already
minikube status
if ($LASTEXITCODE -ne 0) {
  Write-Output 'Starting up minikube (will create if not existing)'
  # minikube start --driver=docker --memory 5000 --cpus 4 --disk-size 35g
  minikube start --driver=$MINIKUBE_DRIVER --memory $MINIKUBE_MEM --cpus $MINIKUBE_CPUS --disk-size $MINIKUBE_DISK
  if ($LASTEXITCODE -ne 0) {
    Write-Output "Cannot start minikube, exiting..."
    exit
  }
}

# Ensure minikube is running before going forward
Write-Output "--------------------------"
Write-Output "Minikube status:"
minikube status
if ($LASTEXITCODE -ne 0) {
  Write-Output "Minikube not running, exiting..."
  exit
}
Write-Output "--------------------------"

Write-Output "Enabling dashboard in minikube"
minikube addons enable metrics-server
minikube addons enable dashboard
# minikube addons disable ingress

# Stop minikube
# minikube stop

# Start minikube again with correct api-server-name to create correct certs for api
# minikube start # --apiserver-name=kubeapi.$IP.nip.io

# Wait until system is ready again
kubectl rollout status deployment/kubernetes-dashboard -n kubernetes-dashboard
kubectl rollout status deployment/coredns -n kube-system

# Check if secret exists
kubectl get secret wildcard-testing-selfsigned-tls-$IP
if ($LASTEXITCODE -ne 0) {
  # Store secret in kubernetes
  kubectl create secret tls wildcard-testing-selfsigned-tls-$IP --cert=./certs/$IP-nip.fullchain.crt --key=./certs/$IP-nip.key
  kubectl create secret tls wildcard-testing-selfsigned-tls-$IP --cert=./certs/$IP-nip.fullchain.crt --key=./certs/$IP-nip.key -n kube-system
  # For nginx ssl ingress
  kubectl create secret tls default-ssl-certificate --cert=./certs/$IP-nip.fullchain.crt --key=./certs/$IP-nip.key -n kube-system
}
kubectl get secret ca-testing-selfsigned-tls

if ($LASTEXITCODE -ne 0) {
  # Store secret in kubernetes
  kubectl create secret generic ca-testing-selfsigned-tls --from-file=kubernetes-dev-self-ca.crt=./certs/kubernetes-dev-self-ca.crt
}

# If using traefik ingress, use helm chart with provided values.
if ($USENGINX -eq 'y') {
  # # If using nginx-ingress with ssl, do this:
  # mkdir ~/.minikube/addons/ingress-ssl -ea 0
  # (Get-Content(./ingress/ingress-ssl-dp_template.yaml)) -replace '__IP__', $IP | Set-Content ./ingress/ingress-ssl-dp.yaml
  # Copy-Item ./ingress/*.yaml ~/.minikube/addons/ingress-ssl/ -Force
  # kubectl rollout status deployment/nginx-ingress-controller --namespace kube-system
  Write-Output "Using internal Nginx in minikube..."
  Write-Output "--------------------------------------------------------------"
  Write-Output "Enter 'kube-system/default-ssl-certificate' without the qoutes"
  Write-Output "--------------------------------------------------------------"
  minikube addons configure ingress
  Write-Output "--------------------------------------------------------------"
  minikube addons enable ingress
} else {
  Write-Output "Installing traefik Ingress"

  # Read certificate and key and write as base64
  $data = Get-Content("./certs/$IP-nip.fullchain.crt")
  $BASE64SSLCERT= [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes( $data ) )
  $data = Get-Content("./certs/$IP-nip.key")
  $BASE64SSLPRIVATEKEY= [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes( $data ) )

  $a = Get-Content("traefik_values_template.yaml")
  $a.replace('__IP__', $IP).replace('__BASE64SSLCERT__', $BASE64SSLCERT).replace('__BASE64SSLPRIVATEKEY__', $BASE64SSLPRIVATEKEY) | Set-Content traefik_values.yaml
  # helm install traefik traefik/traefik

  $a = Get-Content("traefik_dashboard_template.yaml")
  $a.replace('__IP__', $IP) | Set-Content traefik_dashboard.yaml

  Clear-Variable a

  helm upgrade --install --values ./traefik_values.yaml traefik traefik/traefik
  kubectl rollout status deployment/traefik
  kubectl apply -f traefik_dashboard.yaml
}


# Don't require auth for settings on dashboard
kubectl patch deployment kubernetes-dashboard -n kubernetes-dashboard  --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args", "value": [--disable-settings-authorizer]}]'
kubectl patch deployment kubernetes-dashboard -n kubernetes-dashboard --patch "$(Get-Content('dashboard-image-patch.yaml') -Raw)"
# List 30 items per page on dashboard as default
# kubectl apply -f dashboard-settings.yaml -n kubernetes-dashboard

# Replace __IP__ in dashboard-ingress_template.yaml
# Create dashboard ingress
if ($USENGINX -eq 'y') {
  # Ngninx
  (Get-Content("dashboard-ingress_template.yaml")) -replace '__IP__', $IP | kubectl apply -n kube-system -f -
} else {
  # Traefik
  (Get-Content("dashboard-ingress_traefik_template.yaml")) -replace '__IP__', $IP | kubectl apply -n kubernetes-dashboard -f -
}

# Install mailhog for e-mails from gitlab
(Get-Content("mailhog_values_template.yaml")) -replace'__IP__', $IP | Set-Content('mailhog_values.yaml')
helm upgrade --install --values ./mailhog_values.yaml mailhog leifcr/mailhog

exit

# Replace __IP__ in gitlab/values-minikube_template.yaml
(Get-Content("./gitlab/values-minikube_template.yaml")) -replace '__IP__', $IP | Set-Content('./gitlab/values-minikube.yaml')

# This has to be tested further
# kubectl create secret generic gitlab-gitlab-initial-root-password --from-literal=password=$(echo kubedevelop | head -c 11)
kubectl create secret generic gitlab-gitlab-initial-root-password --from-literal=password=kubedevelop

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

if ($USENGINX -eq 'y') {
  # Ngninx
} else {
  # Remove ngnix class + provider requirements for gitlab, as we are running traefik
  # Traefik
  kubectl patch ingress gitlab-registry --type='json' -p='[{"op": "remove", "path": "/metadata/annotations"}]'
  kubectl patch ingress gitlab-minio --type='json' -p='[{"op": "remove", "path": "/metadata/annotations"}]'
  kubectl patch ingress gitlab-unicorn --type='json' -p='[{"op": "remove", "path": "/metadata/annotations"}]'
}

# Check that runner successfully registers, after patching unicorn, minio and registry
kubectl rollout status deployment/gitlab-gitlab-runner

# Create postgres external access
(Get-Content(gitlab/gitlab-postgres-external_template.yaml)) -replace '__IP__', $IP | kubectl create -f -

# Open shell on port 2222
(Get-Content(gitlab/gitlab-shell-service-external-ip_template.yaml)) -replace '__IP__', $IP | kubectl create -f -

# TODO
# Setup kubernetes service account for gitlab
# ./gitlab/setup_kube_account.sh

# Print gitlab info
# ./gitlab/gitlab_info.sh

# Print gitlab kubernetes integration info
# ./gitlab/setup_info.sh

Write-Output "----------------------------------------------------------------------------------------------------------"
Write-Output "Domains for test apps:"
Write-Output "   app1.$IP.nip.io"
Write-Output "   app2.$IP.nip.io"
Write-Output "   service1.$IP.nip.io"
Write-Output "   service2.$IP.nip.io"
Write-Output "----------------------------------------------------------------------------------------------------------"

# echo "URL: https://minio.$IP.nip.io"

# All good?
Write-Output "----------------------------------------------------------------------------------------------------------"
Write-Output "Remember to install the CA certs where needed (likely on your devel computer)"
Write-Output "Also remember to set allow requests to local network in gitlab here: /admin/application_settings/network"
Write-Output "----------------------------------------------------------------------------------------------------------"

# Use tunnel instead and fix all certificates to use 127.0.0.1.nip.io
# Fix dns on windows
# After adding ingress-dns
# minikube addons enable ingress-dns
# remove dns
# Get-DnsClientNrptRule | Where-Object {$_.Namespace -eq '.test'} | Remove-DnsClientNrptRule -Force
# Get-DnsClientNrptRule | Where-Object {$_.Namespace -eq '.test'} | Remove-DnsClientNrptRule -Force; Add-DnsClientNrptRule -Namespace ".test" -NameServers "$(minikube ip)"
