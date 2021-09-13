#!/bin/sh
echo "Creating CA and local certificates"
set -e

if [ "$#" -ne 1 ]
then
  echo "Usage: Must supply ip"
  exit 1
fi

# DOMAIN=$1
IP=$1
cd ./certs

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
DNS.2 = *.$IP.nip.io
DNS.3 = *.production.$IP.nip.io
DNS.4 = *.staging.$IP.nip.io
DNS.5 = *.development.$IP.nip.io
DNS.6 = gitlab.$IP.nip.io
DNS.7 = *.gitlab.$IP.nip.io
DNS.8 = minio.$IP.nip.io
DNS.9 = registry.$IP.nip.io
DNS.10 = app1.$IP.nip.io
DNS.11 = app2.$IP.nip.io
DNS.12 = service1.$IP.nip.io
DNS.13 = service2.$IP.nip.io
DNS.14 = dashboard.$IP.nip.io
DNS.15 = mailhog.$IP.nip.io
DNS.15 = traefik.$IP.nip.io
IP.1 = $IP
IP.2 = 10.96.0.1
IP.3 = 10.0.0.1
EOF

  openssl genrsa -out $IP-nip.key 2048
  openssl req -new -key $IP-nip.key -out $IP-nip.csr -subj "/CN=*.$IP.nip.io/O=Kubernetes Minikube Gitlab Testing./ST=Castle/L=Across Water/OU=Office/C=DK"

  openssl x509 -req -in $IP-nip.csr -CA kubernetes-dev-self-ca.crt -CAkey kubernetes-dev-self-ca.key -CAcreateserial -out $IP-nip.crt -days 1825 -sha256 -extfile $IP-nip.ext -extensions req_ext

  echo "\nCertificate created for"
  echo "*.$IP.nip.io"
  echo "$IP.nip.io"
  echo "*.production.$IP.nip.io"
  echo "*.staging.$IP.nip.io"
  echo "*.development.$IP.nip.io"
  echo "gitlab.$IP.nip.io"
  echo "*.gitlab.$IP.nip.io"
  echo "minio.$IP.nip.io"
  echo "registry.$IP.nip.io"
  echo "app1.$IP.nip.io"
  echo "app2.$IP.nip.io"
  echo "service1.$IP.nip.io"
  echo "service2.$IP.nip.io"
  echo "dashboard.$IP.nip.io"
  echo "mailhog.$IP.nip.io"
  echo "traefik.$IP.nip.io"
  echo "$IP"
  echo "10.96.0.1"
  echo "10.0.0.1\n"

  cat $IP-nip.crt > $IP-nip.fullchain.crt
  cat kubernetes-dev-self-ca.crt >> $IP-nip.fullchain.crt
else
  echo "Certificate already exists\n"
fi

cd ..
