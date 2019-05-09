# minikube with gitlab

This creates a minikube kubernetes cluster with gitlab setup, for development and testing purposes

Requirements:
  * [minikube](https://github.com/kubernetes/minikube)
  * [virtualbox](https://virtualbox.org) (Other minikube setups might work, but are not tested)
  * [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
  * [helm](https://docs.helm.sh/using_helm/#installing-helm) and [helm releases](https://github.com/helm/helm/releases)

After you have all the above, simply call ```setup.sh```

For cleanup, call ```cleanup.sh```

This should NEVER be used in production by any chance, as it has unsafe passwords, secrets and access to the kubernetes dashboard + cluster.

Setup will state url's + passwords

Default credentials for gitlab:
  * *username*: root
  * *password*: kubedevelop

This is provided AS-IS.

## Ingress

Default ingress service is setup to use [Traefik](https://traefik.io/)

To use Nginx as ingress instead, run setup with NGINXINGRESS=true
``` NGINXINGRESS=true setup.sh ```
