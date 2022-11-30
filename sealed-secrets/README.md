![secret](secret.png)

## Sealed Secrets

[Sealed Secrets](https://github.com/bitnami/sealed-secrets) are a "one-way" encrypted Secret that can be created by anyone, but can _only_ be decrypted by the controller running in the target cluster. **The Sealed Secret is safe to share publicly**, upload to git repositories, post to twitter, etc. Once the SealedSecret is safely uploaded to the target Kubernetes cluster, the sealed secrets controller will decrypt it and recover the original Secret.

The SealedSecrets implementation consists of two components:

-   A controller that runs in-cluster, and implements a new SealedSecret Kubernetes API object via the "third party resource" mechanism.
-   A  `kubeseal`  command line tool that encrypts a regular Kubernetes Secret object (as YAML or JSON) into a SealedSecret.

Once decrypted by the controller,  **the enclosed Secret can be used exactly like a regular K8s Secret**  (it  _is_  a regular K8s Secret at this point!). If the SealedSecret object is deleted, the controller will garbage collect the generated Secret.

**Install Sealed Secrets Controller**
```bash
# Add sealed secrets bitnami repo to Helm
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm update
helm install sealed-secrets -n kube-system --set-string fullnameOverride=sealed-secrets-controller sealed-secrets/sealed-secrets
```

**Install Sealed Secrets CLI**

See  [the website](https://github.com/bitnami/sealed-secrets)  for latest version of the CLI and additonal installation instructions.

```bash
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.19.2/kubeseal-0.19.2-linux-amd64.tar.gz
tar -xzvf kubeseal-0.19.2-linux-amd64.tar.gz
sudo mv kubeseal /usr/local/bin/
```

**Usage**

The  `kubeseal`  tool reads the JSON/YAML representation of a Secret on stdin, and produces the equivalent (encrypted) SealedSecret on stdout. A Secret can be created in many ways, but one of the easiest is using  `kubectl create secret --dry-run`, as shown in the following example. Note again that the  `kubectl --dry-run`  just creates a local file and doesn't upload anything to the cluster.

```bash
#Creates an example secret and encrypt it immediately: 
kubectl create secret generic mysecret --dry-run=client --from-literal=password=supersecret -o yaml | kubeseal -o yaml > mysealedsecret.yaml

# Safe to upload mysealedsecret.yaml to git, etc.

# Eventually upload mysealedsecret to cluster: 
kubectl create -f mysealedsecret.yaml 

# The original secret now exists in the cluster.
kubectl get secret mysecret
```
