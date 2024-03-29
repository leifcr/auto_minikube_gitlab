# Initial params
Param($MINIKUBE_MEM=30000, $MINIKUBE_CPUS=8, $MINIKUBE_DISK='75g', $MINIKUBE_DRIVER='hyperv', $USENGINX='n')

# Set config
Write-Output "Minikube config: Memory: $MINIKUBE_MEM CPUS $MINIKUBE_CPUS DISK: $MINIKUBE_DISK DRIVER: $MINIKUBE_DRIVER NGINX: $USENGINX"
$confirmation = Read-Host "Proceed with given configuration?"
if ($confirmation -ne 'y') {
  exit
}

# Total cleanup?
$confirmation = Read-Host "Delete previous minikube and remove all certificates?"
if ($confirmation -eq 'y') {
  minikube status
  if ($LASTEXITCODE -ne 0) {
    Write-Output "Minikube not running, nothing to stop, will delete if existing"
    minikube delete
  } else {
    Write-Output "Minikube running, will stop, then delete"
    minikube stop && minikube delete
  }
  if (Test-Path './certs' -PathType container) {
    Remove-Item -LiteralPath ./certs -Force -Recurse
  }
}

# Update helm repos

# Add traefik
if ($USENGINX -ne 'y') {
  helm repo add traefik https://helm.traefik.io/traefik
}
# Add mailhog repo
helm repo add mailhog https://leifcr.github.io/codecentric-helm-charts
# Add gitlab repo
helm repo add gitlab https://charts.gitlab.io/
helm repo add leifcr-gitlab-agent https://gitlab.com/api/v4/projects/37515071/packages/helm/stable
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
  if (Test-Path '~/.minikube/addons/ingress-ssl' -PathType container) {
    Write-Output "Traefik Ingress used, will remove nginx ingress ssl addon, as it has been found enabled"
    Remove-Item -LiteralPath ~/.minikube/addons/ingress-ssl -Force -Recurse
  }
}

# Copy-Item ./certs/$IP-nip.crt ~/.minikube/files/etc/ssl/certs/registry.$IP.nip.io.pem -Force

# Create certs first if using docker. Note: gitlab runner will not work, and you cannot deploy from gitlab to minikube...
if ($MINIKUBE_DRIVER -eq 'docker') {
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
  Copy-Item ./certs/kubernetes-dev-self-ca.crt ~/.minikube/files/etc/docker/certs.d/registry.$IP.nip.io/ca.crt -Force
}

# Start minikube
# Check if minikube is running already
minikube status
if ($LASTEXITCODE -ne 0) {
  Write-Output 'Starting up minikube (will create if not existing)'
  # minikube start --driver=docker --memory 5000 --cpus 4 --disk-size 35g
  if ($MINIKUBE_DRIVER -eq 'hyperv') {
    minikube start --driver=$MINIKUBE_DRIVER --memory $MINIKUBE_MEM --cpus $MINIKUBE_CPUS --disk-size $MINIKUBE_DISK --hyperv-use-external-switch
  } else {
    minikube start --driver=$MINIKUBE_DRIVER --memory $MINIKUBE_MEM --cpus $MINIKUBE_CPUS --disk-size $MINIKUBE_DISK
  }
  if ($LASTEXITCODE -ne 0) {
    Write-Output "Cannot start minikube, exiting..."
    exit
  }
}

if ($MINIKUBE_DRIVER -ne 'docker') {
  $IP=minikube ip
  ./certs.ps1 $IP
  Write-Output "Generating certificats for ip $IP";
  Write-Output "Stopping minikube..."
  minikube stop

  # Copy certs for docker engine
  mkdir ~/.minikube/files/etc/docker/certs.d/registry.$IP.nip.io -ea 0
  Copy-Item ./certs/kubernetes-dev-self-ca.crt ~/.minikube/files/etc/docker/certs.d/registry.$IP.nip.io/ca.crt -Force

  Write-Output "Starting minikube again..."
  minikube start --embed-certs
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
  # For gitlab-runner
  kubectl create secret generic gitlab-runner-certs --from-file=gitlab.$IP.nip.io.crt=./certs/$IP-nip.fullchain.crt

  # For nginx ssl ingress
  kubectl create secret tls default-ssl-certificate --cert=./certs/$IP-nip.fullchain.crt --key=./certs/$IP-nip.key -n kube-system
}

kubectl get secret ca-testing-selfsigned-tls
if ($LASTEXITCODE -ne 0) {
  # Store secret in kubernetes
  kubectl create secret generic ca-testing-selfsigned-tls --from-file=kubernetes-dev-self-ca.crt=./certs/kubernetes-dev-self-ca.crt
}

# This can give an error, but error can be ignored
kubectl create namespace gitlab-agent
# Create namespace for gitlab-agent and apply cert there
kubectl get secret ca-testing-selfsigned-tls --namespace gitlab-agent
if ($LASTEXITCODE -ne 0) {
  # Store secret in kubernetes
  kubectl create configmap self-signed-ca-cert.crt --from-file=self-signed-ca-cert.crt=./certs/kubernetes-dev-self-ca.crt --namespace gitlab-agent
}

kubectl get secret gitlab-runner-self-signed
if ($LASTEXITCODE -ne 0) {
  # Store secret in kubernetes
  kubectl create secret generic gitlab-runner-self-signed --from-file=gitlab.$IP.nip.io.crt=./certs/kubernetes-dev-self-ca.crt --from-file=registry.$IP.nip.io.crt=./certs/kubernetes-dev-self-ca.crt
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

  Clear-Variable a

  helm upgrade --install --values ./traefik_values.yaml traefik traefik/traefik
  kubectl rollout status deployment/traefik

  Write-Output "Adding dashboard ingresses (both http and https)"
  $a = Get-Content("traefik_dashboard_template_http.yaml")
  $a.replace('__IP__', $IP) | Set-Content traefik_dashboard_http.yaml

  Clear-Variable a

  $a = Get-Content("traefik_dashboard_template_https.yaml")
  $a.replace('__IP__', $IP) | Set-Content traefik_dashboard_https.yaml

  Clear-Variable a

  kubectl apply -f traefik_dashboard_http.yaml
  kubectl apply -f traefik_dashboard_https.yaml

  Write-Output "Writing default certificate"

  $a = Get-Content("traefik_default_tls_store_template.yaml")
  $a.replace('__IP__', $IP) | Set-Content traefik_default_tls_store.yaml
  Clear-Variable a
  kubectl apply -f traefik_default_tls_store.yaml
}

# patches moved to yaml patch
# Don't require auth for settings on dashboard
# kubectl patch deployment kubernetes-dashboard -n kubernetes-dashboard  --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args", "value": [--disable-settings-authorizer]}]'
# Patch args - See https://github.com/kubernetes/dashboard/issues/4938
# kubectl patch deployment kubernetes-dashboard -n kubernetes-dashboard  --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args", "value": [--namespace=kubernetes-dashboard]}]'
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
helm upgrade --install --values ./mailhog_values.yaml mailhog mailhog/mailhog

# Replace __IP__ in gitlab/values-minikube_template.yaml
(Get-Content("./gitlab/values-minikube_template.yaml")) -replace '__IP__', $IP | Set-Content('./gitlab/values-minikube.yaml')

# This has to be tested further
# kubectl create secret generic gitlab-gitlab-initial-root-password --from-literal=password=$(echo kubedevelop | head -c 11)
kubectl create secret generic gitlab-gitlab-initial-root-password --from-literal=password='kubedevelop'

# Install gitlab using helm
# Use CE version
# helm upgrade --install gitlab gitlab/gitlab --values ./gitlab/values-minikube.yaml --set gitlab.migrations.image.repository=registry.gitlab.com/gitlab-org/build/cng/gitlab-rails-ce --set gitlab.sidekiq.image.repository=registry.gitlab.com/gitlab-org/build/cng/gitlab-sidekiq-ce --set gitlab.unicorn.image.repository=registry.gitlab.com/gitlab-org/build/cng/gitlab-unicorn-ce --set gitlab.unicorn.workhorse.image=registry.gitlab.com/gitlab-org/build/cng/gitlab-workhorse-ce --set gitlab.task-runner.image.repository=registry.gitlab.com/gitlab-org/build/cng/gitlab-task-runner-ce
helm upgrade --install gitlab gitlab/gitlab --values ./gitlab/values-minikube.yaml

# Wait for gitlab rollout to finish
kubectl rollout status statefulset/gitlab-postgresql
kubectl rollout status deployment/gitlab-minio
kubectl rollout status statefulset/gitlab-redis-master
kubectl rollout status deployment/gitlab-gitlab-shell
kubectl rollout status deployment/gitlab-registry
kubectl rollout status deployment/gitlab-sidekiq-all-in-1-v1
kubectl rollout status deployment/gitlab-webservice-default

# Check that runner successfully registers, after patching unicorn, minio and registry
kubectl rollout status deployment/gitlab-gitlab-runner

# Create postgres external access
(Get-Content("gitlab\gitlab-postgres-external_template.yaml")) -replace '__IP__', $IP | kubectl create -f -

# Open shell on port 2222
(Get-Content("gitlab\gitlab-shell-service-external-ip_template.yaml")) -replace '__IP__', $IP | kubectl create -f -

# Setup kubernetes service account for gitlab
.\gitlab\setup_kube_account.ps1

# Print gitlab info
.\gitlab\gitlab_info.ps1

# Token setup is deprecated...
# .\gitlab\setup_info.ps1
Write-Output "----------------------------------------------------------------------------------------------------------"
Write-Output "Remember to deploy gitlab-agent, as token setup is deprecated"
Write-Outout "Note: The current gitlab repo has poor support for self signed certificates. Using leifcr repo instead"
Write-Outout "The current certificate is written to self-signed-ca-cert.crt (configmap)"
Write-Output "1. Create a group Example: 'test-group'"
Write-Output "2. Create a project called 'gitlab-agent'"
Write-Output "3. Create config.yaml with the following content in folder .gitlab/agent/test-kubernetes-cluster-agent"
Write-Output "ci_access:"
Write-Output "  groups:"
Write-Output "    - id: test-group"
Write-Output "4. Push the repository"
Write-Output "5. Goto the repository, click 'Infrastructure -> Kubernetes clusters -> Connect a cluster'"
Write-Output "6. Select 'test-kubernetes-cluster-agent'"
Write-Output "7. Copy the token to somewhere, as you need it to register the agent"
Write-Output "8. Install the agent with helm"
Write-Output "9. Add leifcr-gitlab-agent helm chart to support self signed certificates (This script has added it)"
Write-Output "Command 'helm upgrade --install test-kubernetes-cluster-agent leifcr-gitlab-agent/gitlab-agent --namespace gitlab-agent --create-namespace --set image.tag=v15.1.0 --set config.token=PASTE_THE_TOKEN_HERE --set config.kasAddress=wss://kas.$IP.nip.io --set config.caCert='self-signed-ca-cert.crt'"
Write-Output "This config gives access to all projects under 'test-group' to enable kubernetes integration"
Write-Output "----------------------------------------------------------------------------------------------------------"

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
