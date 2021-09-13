Write-Output "Creating CA certificates"

mkdir ./certs -ea 0
Set-Location ./certs
# Only create CA unless it exists
if (Test-Path kubernetes-dev-self-ca.crt -PathType Leaf) {
  Write-Output "CA Certificate already exists"
} else {
  # Creating CA
  openssl genrsa -out kubernetes-dev-self-ca.key 2048
  openssl req -x509 -new -nodes -key kubernetes-dev-self-ca.key -sha256 -days 1825 -out kubernetes-dev-self-ca.crt -subj "/CN=Dev Kubernetes CA/O=Kubernetes Testing CA/ST=Castle/L=Tower/OU=Guard/C=DK" -config ../ca_config.conf
  # openssl x509 -inform pem -in kubernetes-dev-self-ca.pem -outform der -out kubernetes-dev-self-ca.crt
  # openssl x509 -in kubernetes-dev-self-ca.crt -inform der -text -noout
  # openssl x509 -in kubernetes-dev-self-ca.pem -inform pem -text -noout
}

Set-Location ..
