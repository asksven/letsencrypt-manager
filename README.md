# Let's ecnrypt manager

This project offers an easy way to have Let's Encrypt certificates generated and maitained for any internet-facing app. This comes-in handy if you don't have an ingress controller that manages SSL certificates for you, or if you are deploying an ingress with a hostname that can not be managed by your ingress controller.
We use http-01 for fifilling the challenge.

See also:
- https://github.com/staticfloat/docker-nginx-certbot

## Deploy

### Pre-requisites

#### Custom role

Prio to deploying, a custom role, a service account and a role binding need to be created in the target namespace. The service account will have the permissions to update the secret and the deployment.

If the let's encrypt manager instance is going to be installed in the namespace `$NAMESPACE`, create the role by running:

```
kubectl -n $NAMESPACE apply -f admin/certbot-role.yaml

```
### Deploy the let's encrypt manager

1. In the namespace `$NAMESPACE` identity the name of the service, its port, the name of the deployment the ingress will point to, as well as the name of the already present ingress (will be replaced) 
1. make a copy of `ops/variables/example.yaml` and point the environment variables `DEPLOY_ENV` to the name of that files, e.g. `export DEPLOY_ENV=status-prd`
1. Edit the `DEPLOY_ENV` file and replace `hostname` with the FQDN you are requesting a certificate for, give `project` a name (only lowercase letters), name `service.name` and `deployment` based on the target objects to be pointed to, set `service.port` to the service port the ingress should be pointing at, and `ingress.name` to the name of the already existing ingress
1. set `certbot.test` to `1` to test against the Let's Encrypt staging environment (recommended for firet tries), or to `0` for Let's Encrypt production
1. set `certbot.email` to your e-mail addresse
1. go to `ops` and run `./deploy.sh` (jinja2 and yq required)

#### Troubeshoting

1. Check if the job that requests the initial certificate has run
1. Check if the cronjob runs
1. If you want to switch from stage to production you need to delete the pvc 

### Architecture

This project can be deployed to a namespace containing a service and a deployment das well as an ingress pointing to the service.

What the project adds to the namespace:

1. a service account with permissions to overwrite the ingress' TLS secret (`admin/certbot-role.yaml`)
1. a replacement ingress pointing to the existing service (`ops/manifests/ingress.yaml`)
1. an initial self signed certificate (generated in `ops/deploy.sh`)
1. a job that requests a Let's encrypt certificate for the `hostname` (`ops/manifests/certbot-job.yaml`)
1. a service pointing to the job and references by the ingress under the `/.well-known` URL to fulfill the http-01 challenge (`ops/manifests/certbot-service.yaml`) 
1. a cronjob running daily to check if the certificate needs to be renewed (`ops/manifests/certbot-cronjob.yaml`)
1. a persisitent volume claim to store the cerbot state (`ops/manifests/cert-pvc.yaml`)
