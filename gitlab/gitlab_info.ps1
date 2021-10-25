$IP=$(minikube ip)
$pw = $(kubectl get secret gitlab-gitlab-initial-root-password -o jsonpath="{.data.password}")
$pw = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($pw))
$postgresqlpw = $(kubectl get secret gitlab-postgresql-password -o jsonpath="{.data.postgresql-password}")
$postgresqlpw = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($postgresqlpw))
$postgrespw = $(kubectl get secret gitlab-postgresql-password -o jsonpath="{.data.postgresql-postgres-password}")
$postgrespw = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($postgrespw))
Write-Output "----------------------------------------------"
Write-Output "Gitlab info:"
Write-Output "----------------------------------------------"
Write-Output "Root password: $pw"
Write-Output "URLs:"
Write-Output "    Gitlab HTTPS: https://gitlab.$IP.nip.io"
Write-Output "           HTTP:  http://gitlab.$IP.nip.io"
Write-Output "Dashboard  HTTPS: https://dashboard.$IP.nip.io"
Write-Output "           HTTP:  http://dashboard.$IP.nip.io"
Write-Output "Minio      HTTPS: https://minio.$IP.nip.io"
Write-Output "           HTTP:  http://minio.$IP.nip.io"
Write-Output "Mailhog    HTTP:  http://mailhog.$IP.nip.io"
Write-Output "Minikube IP: $IP"
Write-Output "Postgres port: 5432"
Write-Output "         database gitlabhq_production"
Write-Output "         username: gitlab"
Write-Output "         password: $postgresqlpw"
Write-Output "Postgres pw: $postgrespw"
Write-Output "----------------------------------------------"
