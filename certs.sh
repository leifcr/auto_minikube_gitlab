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

cat > ca.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:TRUE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment

[ extend ]
extendedKeyUsage =serverAuth, clientAuth, codeSigning, emailProtection
EOF

# Creating CA
openssl genrsa -out myCA.key 2048
openssl req -x509 -new -nodes -key myCA.key -sha256 -days 1825 -out myCA.pem -subj "/CN=CA.$IP.nip.io/O=Kubernetes Testing CA./ST=Castle/L=Tower/OU=Guard/C=DK"

# If certificates exists, delete
openssl genrsa -out $IP-nip.key 2048
openssl req -new -key $IP-nip.key -out $IP-nip.csr -subj "/CN=$IP.nip.io/O=Kubernetes Minikube Gitlab Testing./ST=Castle/L=Across Water/OU=Office/C=DK"

cat > $IP-nip.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment

[ extend ]
extendedKeyUsage =serverAuth, clientAuth, codeSigning, emailProtection

[ req_ext ]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $IP
DNS.2 = $IP.nip.io
DNS.3 = gitlab.$IP.nip.io
DNS.4 = minio.$IP.nip.io
DNS.5 = registry.$IP.nip.io
DNS.6 = app1.$IP.nip.io
DNS.7 = app2.$IP.nip.io
DNS.8 = service1.$IP.nip.io
DNS.9 = service2.$IP.nip.io
EOF

openssl x509 -req -in $IP-nip.csr -CA myCA.pem -CAkey myCA.key -CAcreateserial -out $IP-nip.crt -days 1825 -sha256 -extfile $IP-nip.ext -extensions req_ext

echo "Certificate created for\n\n"
echo "$IP"
echo "$IP.nip.io"
echo "gitlab.$IP.nip.io"
echo "minio.$IP.nip.io"
echo "registry.$IP.nip.io"
echo "app1.$IP.nip.io"
echo "app2.$IP.nip.io"
echo "service1.$IP.nip.io"
echo "service2.$IP.nip.io"

cat $IP-nip.crt > $IP-nip.fullchain.crt
cat myCA.pem >> $IP-nip.fullchain.crt

ls -l
cd ..

echo "\nRemember to install the CA where needed..."
