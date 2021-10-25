# minikube with gitlab

This creates a minikube kubernetes cluster with gitlab setup, for development and testing purposes

Requirements:
  * [minikube](https://github.com/kubernetes/minikube)
  * [docker](https://docker.com) (Other minikube setups might work, but are not tested)
  * [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
  * [helm](https://helm.sh/docs/intro/install/) and [helm releases](https://github.com/helm/helm/releases)

After you have all the above, simply call ```setup.ps1```

You can provide the following parameters in order:
  * Memory in megabytes (Default 15000)
  * Number of cpu threads (Default 6)
  * Diskspace (Default 35g)
  * Driver (Default docker)
  * Use nginx (Default n, as traefik is preferred)

Note: Nginx setup is not tested fully

This should NEVER be used in production by any chance, as it has unsafe passwords, secrets and access to the kubernetes dashboard + cluster.

Setup will state url's + passwords

Default credentials for gitlab:
  * *username*: root
  * *password*: kubedevelop

This is provided AS-IS.

## Ingress

Default ingress service is setup to use [Traefik](https://traefik.io/)

## Accessing the cluster

In order to access the cluster, call ```minikube tunnel```

## Domains/URLS

#### These are setup out of the box
  * gitlab.127.0.0.1.nip.io
  * minio.127.0.0.1.nip.io
  * registry.127.0.0.1.nip.io
  * dashboard.127.0.0.1.nip.io
  * mailhog.127.0.0.1.nip.io
  * traefik.127.0.0.1.nip.io

### These can be used for testing

  * production.127.0.0.1.nip.io
  * staging.127.0.0.1.nip.io
  * development.127.0.0.1.nip.io
  * app1.127.0.0.1.nip.io
  * app2.127.0.0.1.nip.io
  * service1.127.0.0.1.nip.io
  * service2.127.0.0.1.nip.io

