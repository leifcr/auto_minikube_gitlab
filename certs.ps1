#!/bin/sh
Write-Output "Creating CA and local certificates"
Param($CREATE_IP)

try {
  [IPAddress] $CREATE_IP
  Write-Output "Creating certificates for $CREATE_IP"
}
catch {
  throw "Cannot typecast variable to IPAddress"
}

Set-Location ./certs
if (Test-Path $CREATE_IP-nip.key --PathType Leaf) {
  Write-Output "Certificate already exists..."
} else {

@"
[ req_ext ]
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage=digitalSignature, keyEncipherment
extendedKeyUsage=serverAuth, clientAuth
subjectAltName=@alt_names

[alt_names]
DNS.1 = $CREATE_IP.nip.io
DNS.2 = *.$CREATE_IP.nip.io
DNS.3 = *.production.$CREATE_IP.nip.io
DNS.4 = *.staging.$CREATE_IP.nip.io
DNS.5 = *.development.$CREATE_IP.nip.io
DNS.6 = gitlab.$CREATE_IP.nip.io
DNS.7 = *.gitlab.$CREATE_IP.nip.io
DNS.8 = minio.$CREATE_IP.nip.io
DNS.9 = registry.$CREATE_IP.nip.io
DNS.10 = app1.$CREATE_IP.nip.io
DNS.11 = app2.$CREATE_IP.nip.io
DNS.12 = service1.$CREATE_IP.nip.io
DNS.13 = service2.$CREATE_IP.nip.io
DNS.14 = dashboard.$CREATE_IP.nip.io
DNS.15 = mailhog.$CREATE_IP.nip.io
DNS.15 = traefik.$CREATE_IP.nip.io
IP.1 = $CREATE_IP
IP.2 = 10.96.0.1
IP.3 = 10.0.0.1
"@ | Set-Content("$CREATE_IP-nip.key")

  openssl genrsa -out $CREATE_IP-nip.key 2048
  openssl req -new -key $CREATE_IP-nip.key -out $CREATE_IP-nip.csr -subj "/CN=*.$CREATE_IP.nip.io/O=Kubernetes Minikube Gitlab Testing./ST=Castle/L=Across Water/OU=Office/C=DK"

  openssl x509 -req -in $CREATE_IP-nip.csr -CA kubernetes-dev-self-ca.crt -CAkey kubernetes-dev-self-ca.key -CAcreateserial -out $CREATE_IP-nip.crt -days 1825 -sha256 -extfile $CREATE_IP-nip.ext -extensions req_ext

  Write-Output "Certificate created for"
  Write-Output ""
  Write-Output "*.$CREATE_IP.nip.io"
  Write-Output "$CREATE_IP.nip.io"
  Write-Output "*.production.$CREATE_IP.nip.io"
  Write-Output "*.staging.$CREATE_IP.nip.io"
  Write-Output "*.development.$CREATE_IP.nip.io"
  Write-Output "gitlab.$CREATE_IP.nip.io"
  Write-Output "*.gitlab.$CREATE_IP.nip.io"
  Write-Output "minio.$CREATE_IP.nip.io"
  Write-Output "registry.$CREATE_IP.nip.io"
  Write-Output "app1.$CREATE_IP.nip.io"
  Write-Output "app2.$CREATE_IP.nip.io"
  Write-Output "service1.$CREATE_IP.nip.io"
  Write-Output "service2.$CREATE_IP.nip.io"
  Write-Output "dashboard.$CREATE_IP.nip.io"
  Write-Output "mailhog.$CREATE_IP.nip.io"
  Write-Output "traefik.$CREATE_IP.nip.io"
  Write-Output "$CREATE_IP"
  Write-Output "10.96.0.1"
  Write-Output "10.0.0.1"
  Write-Output ""

  Get-Content $CREATE_IP-nip.crt, kubernetes-dev-self-ca.crt | Set-Content $CREATE_IP-nip.fullchain.crt
}

Set-Location ..
