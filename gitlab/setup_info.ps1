$IP=$(minikube ip)
$token_name = kubectl get secrets -n kube-system | Select-String('gitlab-token')
$token_name = $token_name -split " " | Select-String('gitlab-token')
$token = $(kubectl get secret $token_name -o jsonpath="{.data.token}" -n kube-system)
$token = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($token))
$ca = $(kubectl get secret $token_name -o jsonpath="{.data.ca\.crt}" -n kube-system)
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

