Param($IP)

Write-Output "Creating CA and local certificates"

try {
  [IPAddress] $IP
  Write-Output "Creating certificates for $IP"
}
catch {
  throw "Cannot typecast variable to IPAddress"
}

Set-Location ./certs
if (Test-Path "$IP-nip.key" -PathType Leaf) {
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
"@ | Set-Content("$IP-nip.ext")

  openssl genrsa -out $IP-nip.key 2048
  openssl req -new -key $IP-nip.key -out $IP-nip.csr -subj "/CN=*.$IP.nip.io/O=Kubernetes Minikube Gitlab Testing./ST=Castle/L=Across Water/OU=Office/C=UK"

  openssl x509 -req -in $IP-nip.csr -CA kubernetes-dev-self-ca.crt -CAkey kubernetes-dev-self-ca.key -CAcreateserial -out $IP-nip.crt -days 1825 -sha256 -extfile $IP-nip.ext -extensions req_ext

  Write-Output "Certificate created for"
  Write-Output ""
  Write-Output "*.$IP.nip.io"
  Write-Output "$IP.nip.io"
  Write-Output "*.production.$IP.nip.io"
  Write-Output "*.staging.$IP.nip.io"
  Write-Output "*.development.$IP.nip.io"
  Write-Output "gitlab.$IP.nip.io"
  Write-Output "*.gitlab.$IP.nip.io"
  Write-Output "minio.$IP.nip.io"
  Write-Output "registry.$IP.nip.io"
  Write-Output "app1.$IP.nip.io"
  Write-Output "app2.$IP.nip.io"
  Write-Output "service1.$IP.nip.io"
  Write-Output "service2.$IP.nip.io"
  Write-Output "dashboard.$IP.nip.io"
  Write-Output "mailhog.$IP.nip.io"
  Write-Output "traefik.$IP.nip.io"
  Write-Output "$IP"
  Write-Output "10.96.0.1"
  Write-Output "10.0.0.1"
  Write-Output ""

  Get-Content $IP-nip.crt, kubernetes-dev-self-ca.crt | Set-Content $IP-nip.fullchain.crt
}

Set-Location ..
