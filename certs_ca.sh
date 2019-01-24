#!/bin/sh
echo "Creating CA certificates"

mkdir -p ./certs
cd ./certs
# Only create CA unless it exists
if [ ! -f minikube-self-ca.crt ]; then

  # Creating CA
  openssl genrsa -out minikube-self-ca.key 2048
  openssl req -x509 -new -nodes -key minikube-self-ca.key -sha256 -days 1825 -out minikube-self-ca.crt -subj "/CN=Minikube Kubernetes CA/O=Kubernetes Testing CA/ST=Castle/L=Tower/OU=Guard/C=DK" -config ../ca_config.conf
  # openssl x509 -inform pem -in minikube-self-ca.pem -outform der -out minikube-self-ca.crt
  # openssl x509 -in minikube-self-ca.crt -inform der -text -noout
  # openssl x509 -in minikube-self-ca.pem -inform pem -text -noout
else
  echo "CA Certificate already exists\n"
fi

cd ..
