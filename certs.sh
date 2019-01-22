#!/bin/sh
echo "Creating CA and local certificates"

if [ "$#" -ne 1 ]
then
  echo "Usage: Must supply ip"
  exit 1
fi

# DOMAIN=$1
IP=$1
mkdir -p ./certs
cd ./certs
# Only create CA unless it exists
if [ ! -f minikube-self-ca.pem ]; then

  # Creating CA
  openssl genrsa -out minikube-self-ca.key 2048
  openssl req -x509 -new -nodes -key minikube-self-ca.key -sha256 -days 1825 -out minikube-self-ca.crt -subj "/CN=CA.$IP.nip.io/O=Kubernetes Testing CA./ST=Castle/L=Tower/OU=Guard/C=DK" -config ../ca_config.conf
  # openssl x509 -inform pem -in minikube-self-ca.pem -outform der -out minikube-self-ca.crt
  # openssl x509 -in minikube-self-ca.crt -inform der -text -noout
  # openssl x509 -in minikube-self-ca.pem -inform pem -text -noout
else
  echo "CA Certificate already exists\n"
fi

if [ ! -f $IP-nip.key ]; then

cat > $IP-nip.ext << EOF
[ req_ext ]
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage=digitalSignature, keyEncipherment
extendedKeyUsage=serverAuth, clientAuth
subjectAltName=@alt_names

[alt_names]
DNS.1 = $IP.nip.io
DNS.2 = gitlab.$IP.nip.io
DNS.3 = minio.$IP.nip.io
DNS.4 = registry.$IP.nip.io
DNS.5 = app1.$IP.nip.io
DNS.6 = app2.$IP.nip.io
DNS.7 = service1.$IP.nip.io
DNS.8 = service2.$IP.nip.io
DNS.9 = dashboard.$IP.nip.io
IP.1 = $IP
IP.2 = 10.96.0.1
IP.3 = 10.0.0.1
EOF

#   keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
#   extendedKeyUsage = serverAuth, clientAuth, codeSigning, emailProtection

#   cat > apiserver.ext << EOF
#   authorityKeyIdentifier=keyid,issuer
#   basicConstraints=CA:FALSE
#   keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
#   extendedKeyUsage = serverAuth, clientAuth, codeSigning, emailProtection

#   [ extend ]
#   extendedKeyUsage = serverAuth, clientAuth, codeSigning, emailProtection

#   [ req_ext ]
#   subjectAltName = @alt_names

#   [alt_names]
#   DNS.1 = minikubeCA
#   DNS.2 = kubernetes.default.svc.cluster.local
#   DNS.3 = kubernetes.default.svc
#   DNS.4 = kubernetes.default
#   DNS.5 = kubernetes
#   DNS.6 = localhost
#   DNS.7 = $IP.nip.io
#   DNS.8 = kubernetes.$IP.nip.io
#   DNS.9 = minikube.$IP.nip.io
#   IP.1 = $IP
#   IP.2 = 10.96.0.1
#   IP.3 = 10.0.0.1
# EOF

  # If certificates exists, delete ?
  openssl genrsa -out $IP-nip.key 2048
  openssl req -new -key $IP-nip.key -out $IP-nip.csr -subj "/CN=$IP.nip.io/O=Kubernetes Minikube Gitlab Testing./ST=Castle/L=Across Water/OU=Office/C=DK"

  openssl x509 -req -in $IP-nip.csr -CA minikube-self-ca.crt -CAkey minikube-self-ca.key -CAcreateserial -out $IP-nip.crt -days 1825 -sha256 -extfile $IP-nip.ext -extensions req_ext
  openssl x509 -in $IP-nip.crt -text -noout

  # openssl x509 -inform der -in $IP-nip.crt -out $IP-nip.pem

  # openssl genrsa -out apiserver.key 2048
  # openssl req -new -key apiserver.key -out apiserver.csr -subj "/CN=minikube api server/O=Kubernetes Minikube Gitlab Testing./ST=Castle/L=Across Water/OU=Office/C=DK"

  # openssl x509 -req -in apiserver.csr -CA minikube-self-ca.crt -CAkey minikube-self-ca.key -CAcreateserial -out apiserver.crt -days 1825 -sha256 -extfile apiserver.ext -extensions req_ext
  # openssl x509 -inform der -in apiserver.crt -out apiserver.pem

  echo "\nCertificate created for"
  echo "$IP"
  echo "$IP.nip.io"
  echo "gitlab.$IP.nip.io"
  echo "minio.$IP.nip.io"
  echo "registry.$IP.nip.io"
  echo "app1.$IP.nip.io"
  echo "app2.$IP.nip.io"
  echo "service1.$IP.nip.io"
  echo "service2.$IP.nip.io"
  echo "dashboard.$IP.nip.io\n"

  cat $IP-nip.crt > $IP-nip.fullchain.crt
  cat minikube-self-ca.crt >> $IP-nip.fullchain.crt
else
  echo "Certificate already exists\n"
fi

cd ..

echo "\nRemember to install the CA certs where needed (likely on your devel computer)"
