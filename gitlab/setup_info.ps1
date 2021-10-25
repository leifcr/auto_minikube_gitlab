$IP=$(minikube ip)
$token_name = kubectl get secrets | Select-String('default-token')
$token_name = $token_name -split " " | Select-String('default-token')
$token = $(kubectl get secret $token_name -o jsonpath="{.data.token}")
$token = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($token))
$ca = $(kubectl get secret $token_name -o jsonpath="{.data.ca\.crt}")
$ca = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($ca))

Write-Output "Information for gitlab setup of kubernetes cluster"
Write-Output "API  ip: Server: $(kubectl cluster-info | grep 'Kubernetes control plane' | awk '/http/ {print $NF}')"
Write-Output "    url: HTTPS:  https://kubeapi.$IP.nip.io:8443"
Write-Output "         HTTP:   http://kubeapi.$IP.nip.io:8443"
Write-Output "Token:"
Write-Output "$token"
Write-Output ""
Write-Output "CA:"
Write-Output "$ca"
Write-Output ""

Clear-Variable ca
Clear-Variable token_name
Clear-Variable token

