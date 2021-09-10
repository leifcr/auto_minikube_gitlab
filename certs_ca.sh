#!/bin/sh
echo "Creating CA certificates"
set -e

mkdir -p ./certs
cd ./certs
# Only create CA unless it exists
if [ ! -f kubernetes-dev-self-ca.crt ]; then

  # Creating CA
  openssl genrsa -out kubernetes-dev-self-ca.key 2048
  openssl req -x509 -new -nodes -key kubernetes-dev-self-ca.key -sha256 -days 1825 -out kubernetes-dev-self-ca.crt -subj "/CN=Dev Kubernetes CA/O=Kubernetes Testing CA/ST=Castle/L=Tower/OU=Guard/C=DK" -config ../ca_config.conf
  # openssl x509 -inform pem -in kubernetes-dev-self-ca.pem -outform der -out kubernetes-dev-self-ca.crt
  # openssl x509 -in kubernetes-dev-self-ca.crt -inform der -text -noout
  # openssl x509 -in kubernetes-dev-self-ca.pem -inform pem -text -noout
else
  echo "CA Certificate already exists\n"
fi

cd ..
