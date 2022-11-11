
![nginx logo](nginx.jpeg)


## Nginx Ingress Controller

[Ingress](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.25/#ingress-v1-networking-k8s-io)  exposes HTTP and HTTPS routes from outside the cluster to  [services](https://kubernetes.io/docs/concepts/services-networking/service/)  within the cluster. Traffic routing is controlled by rules defined on the Ingress resource.


**Install NGINX ingress controller**

```bash
kubectl create namespace ingress-nginx

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install nginx ingress-nginx/ingress-nginx -n ingress-nginx
```

Example Ingress that makes use of the controller:
```bash
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example
  namespace: foo
spec:
  ingressClassName: nginx
  rules:
    - host: example.com
      http:
        paths:
          - pathType: Prefix
            backend:
              service:
                name: rabbitmq
                port:
                  number: 80
            path: /
  # This section is only required if TLS is to be enabled for the Ingress
  tls:
    - hosts:
      - www.example.com
      secretName: example-tls

If TLS is enabled for the Ingress, a Secret containing the certificate and key must also be provided:

apiVersion: v1
kind: Secret
metadata:
  name: example-tls
  namespace: foo
data:
  tls.crt: <base64 encoded cert>
  tls.key: <base64 encoded key>
type: kubernetes.io/tls
```

**Enable TCP Ingress for MySQL on port 3306**

```bash
# Install MySQL so we have a TCP port we can expose
kubectl create namespace mysql

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install mysql bitnami/mysql -n mysql

# Rertrieve configuration values from NGINX release
helm get values nginx -n ingress-nginx --all > values.yaml

# Change the following in values.yaml
tcp: {}
udp: {}

# To: <tcp-port>: <namespace>/<service>:<tcp-port>
tcp:
  3306: mysql/mysql:3306
udp:{}

# Update NGINX controller using the updated values.yaml file
helm upgrade --install nginx ingress-nginx/ingress-nginx -n ingress-nginx --values values.yaml

# You should see a new ConfigMap created in namespace ingress-nginx named nginx-ingress-nginx-tcp
kubectl get cm -n ingress-nginx
NAME                             DATA   AGE
kube-root-ca.crt                 1      101m
nginx-ingress-nginx-controller   1      100m
nginx-ingress-nginx-tcp          1      3s

# Now you should be able to access MySQL database using a domain name
MYSQL_ROOT_PASSWORD=$(kubectl get secret --namespace mysql mysql -o jsonpath="{.data.mysql-root-password}" | base64 -d)
mysql -h skynetsystems.io -uroot -p"$MYSQL_ROOT_PASSWORD"
```

**NGINX ingress with TLS using Letsencrypt**

We need to install cert-manager to do the work with Kubernetes to request a certificate and respond to the challenge to validate it. We can use Helm or plain Kubernetes manifests to install cert-manager.

cert-manager mainly uses two different custom Kubernetes resources - known as  [`CRDs`](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)  - to configure and control how it operates, as well as to store state. These resources are Issuers and Certificates.

**Issuers**

An Issuer defines  _how_  cert-manager will request TLS certificates. Issuers are specific to a single namespace in Kubernetes, but there's also a  `ClusterIssuer`  which is meant to be a cluster-wide version.

Take care to ensure that your Issuers are created in the same namespace as the certificates you want to create. You might need to add  `-n my-namespace`  to your  `kubectl create`  commands.

Your other option is to replace your  `Issuers`  with  `ClusterIssuers`;  `ClusterIssuer`  resources apply across all Ingress resources in your cluster. If using a  `ClusterIssuer`, remember to update the Ingress annotation  `cert-manager.io/issuer`  to  `cert-manager.io/cluster-issuer`.

If you see issues with issuers, follow the  [Troubleshooting Issuing ACME Certificates](https://cert-manager.io/docs/faq/acme/)  guide.

More information on the differences between  `Issuers`  and  `ClusterIssuers`  - including when you might choose to use each can be found on  [Issuer concepts](https://cert-manager.io/docs/concepts/issuer/#namespaces).

**Certificates**

Certificates resources allow you to specify the details of the certificate you want to request. They reference an issuer to define  _how_  they'll be issued.

For more information, see  [Certificate concepts](https://cert-manager.io/docs/concepts/certificate/).

**Configure a Let's Encrypt Issuer**

We'll set up two issuers for Let's Encrypt in this example: staging and production.

The Let's Encrypt production issuer has  [very strict rate limits](https://letsencrypt.org/docs/rate-limits/). When you're experimenting and learning, it can be very easy to hit those limits. Because of that risk, we'll start with the Let's Encrypt staging issuer, and once we're happy that it's working we'll switch to the production issuer.

Note that you'll see a warning about untrusted certificates from the staging issuer, but that's totally expected.

Create this definition locally and update the email address to your own. This email is required by Let's Encrypt and used to notify you of certificate expiration and updates.

*issuer-letsencrypt-staging.yaml*

```bash
 apiVersion: cert-manager.io/v1
 kind: ClusterIssuer
 metadata:
   name: letsencrypt-staging
 spec:
   acme:
     # The ACME server URL for ClusterIssuer
     server: https://acme-staging-v02.api.letsencrypt.org/directory
     # Email address used for ACME registration
     email: admin@skynetsystems.io
     # Name of a secret used to store the ACME account private key
     privateKeySecretRef:
       name: letsencrypt-staging
     # Enable the HTTP-01 challenge provider
     solvers:
     - http01:
         ingress:
           class: nginx
 ```

Then apply the yaml

```bash
kubectl apply -f issuer-letsencrypt-staging.yaml
```

Also create a production issuer and deploy it:

*issuer-letsencrypt-prod.yaml*

```bash
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
 spec:
  acme:
    # The ACME server URL for ClusterIssuer
    server: https://acme-v02.api.letsencrypt.org/directory
    # Email address used for ACME registration
    email: admin@skynetsystems.io
    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-prod
    # Enable the HTTP-01 challenge provider
    solvers:
    - http01:
        ingress:
          class: nginx
```

```bash
kubectl apply -f issuer-letsencrypt-staging.yaml
```

**Links**

 - [Github: kubernetes/ingress-nginx](https://github.com/kubernetes/ingress-nginx)
 - [Installation Guide](https://kubernetes.github.io/ingress-nginx/deploy/)
 - [Ingress - Kubernetes](https://kubernetes.io/docs/concepts/services-networking/ingress/)
 - [Bitnami - MySQL](https://bitnami.com/stack/mysql/helm)

