
![argocd logo](argocd.png)


#### Commands

```bash
# install ArgoCD in k8s
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# access ArgoCD UI
kubectl get svc -n argocd
kubectl port-forward svc/argocd-server 8443:443 -n argocd

# login with admin user and below token (as in documentation):
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode && echo

# you can change and delete init password

```

#### Ingress
Setting up Ingress for ArgoCD can be tricky if you don't understand what ArgoCD is doing under the hood. The main issue stems from the fact that ArgoCD wants to handle TLS termination by itself. Although the ArgoCD service opens port 80 and port 443, if you try to connect on port 80 you will immediately be asked to redirect to port 443 as ArgoCD forces TLS. Herein lies the problem, an Ingress controller such as NGINX will want to terminate TLS and pass on the unencrypted connection on port 80 to the backend, this does not satisfy ArgoCD's TLS only rule and in turn the request is redirected to port 443. This back and forth ends up in a redirect loop until the browser decides to terminate the request. 

To prevent this redirect loop from occurring we an add an annotation that instructs NGINX to talk to the back end in **HTTPS** and not HTTP.

Below is an example of how this can be accomplished with an NGINX ingress object:

```bash
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-ingress
  namespace: argocd
  annotations:
    ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  ingressClassName: nginx
  rules:
    - host: argocd.h2o-2-2086.h2o.vmware.com
      http:
        paths:
          - pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 443
            path: /
```
#### Links

* Config repo: [https://gitlab.com/nanuchi/argocd-app-config](https://gitlab.com/nanuchi/argocd-app-config)

* Docker repo: [https://hub.docker.com/repository/docker/nanajanashia/argocd-app](https://hub.docker.com/repository/docker/nanajanashia/argocd-app)

* Install ArgoCD: [https://argo-cd.readthedocs.io/en/stable/getting_started/#1-install-argo-cd](https://argo-cd.readthedocs.io/en/stable/getting_started/#1-install-argo-cd)

* Login to ArgoCD: [https://argo-cd.readthedocs.io/en/stable/getting_started/#4-login-using-the-cli](https://argo-cd.readthedocs.io/en/stable/getting_started/#4-login-using-the-cli)

* ArgoCD Configuration: [https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)
