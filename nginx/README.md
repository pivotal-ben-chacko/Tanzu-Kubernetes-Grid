
![nginx logo](nginx.jpeg)


## Nginx Ingress Controller

[Ingress](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.25/#ingress-v1-networking-k8s-io)  exposes HTTP and HTTPS routes from outside the cluster to  [services](https://kubernetes.io/docs/concepts/services-networking/service/)  within the cluster. Traffic routing is controlled by rules defined on the Ingress resource.


**Install NGINX ingress controller**

```bash
kubectl create namespace ingress-nginx
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
      - host: www.example.com
        http:
          paths:
            - pathType: Prefix
              backend:
                service:
                  name: exampleService
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

**Links**

 - [Github: kubernetes/ingress-nginx](https://github.com/kubernetes/ingress-nginx)
 - [Installation Guide](https://kubernetes.github.io/ingress-nginx/deploy/)
 - [Ingress - Kubernetes](https://kubernetes.io/docs/concepts/services-networking/ingress/)
 - [Bitnami - MySQL](https://bitnami.com/stack/mysql/helm)
