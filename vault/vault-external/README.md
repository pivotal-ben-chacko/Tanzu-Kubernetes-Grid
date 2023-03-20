![vault logo](../vault.png)

## # Integrate a Kubernetes Cluster with an External Vault

Vault can manage secrets for Kubernetes application pods from outside the cluster. This could be [HashiCorp Cloud Platform (HCP) Vault](https://developer.hashicorp.com/vault/tutorials/cloud) or another Vault service within your organization.

### Start Vault

 1. Open a new terminal, start a Vault dev server with `root` as the root token that listens for requests at `0.0.0.0:8200`.
 
	 ```
	$ > vault server -dev -dev-root-token-id root -dev-listen-address 0.0.0.0:8200
	 ```

	Setting the `-dev-listen-address` to `0.0.0.0:8200` overrides the default address of a Vault dev server (`127.0.0.1:8200`) and enables Vault to be addressable by the Kubernetes cluster and its pods because it binds to a shared network.

 2. Export an environment variable for the `vault` CLI to address the Vault server.
	 ```
	 $ > export VAULT_ADDR=http://0.0.0.0:8200
	 ```
 
 3. Login with the _root token_.
	 ```
	 $ > vault login root
	 Success! You are now authenticated. The token information displayed below
	is already stored in the token helper. You do NOT need to run "vault login"
	again. Future Vault requests will automatically use this token.

	Key                  Value
	---                  -----
	token                root
	token_accessor       Qt5TxBXUbOQcNwmm5a2WxpEa
	token_duration       ∞
	token_renewable      false
	token_policies       ["root"]
	identity_policies    []
	policies             ["root"]
	```

### Deploy service and endpoints to address the external Vault
An external Vault may not have a static network address that services in the cluster can rely upon. When Vault's network address changes each service also needs to change to continue its operation. Another approach to manage this network address is to define a Kubernetes  [service](https://kubernetes.io/docs/concepts/services-networking/service/)  and  [endpoints](https://kubernetes.io/docs/concepts/services-networking/service/#services-without-selectors).

A  _service_  creates an abstraction around pods or an external service. When an application running in a pod requests the service, that request is routed to the endpoints that share the service name.

 1. First set the following environment variable to the IP address of the host machine hosting vault. In my case this was a VM running HashiCorp Vault in the same network segment as my Kubernetes deployment. This IP address must be routable from your Kubernetes cluster.
 
	```
	$ > EXTERNAL_VAULT_ADDR=<VAULT-HOST-IP>
	```

2. Define a service named `external-vault` and a corresponding endpoint configured to address the `EXTERNAL_VAULT_ADDR` and apply it.

	```
	$ > cat  > external-vault.yaml <<EOF
	---
	apiVersion: v1
	kind: Service
	metadata:
	  name: external-vault
	  namespace: default
	spec:
	  ports:
	  - protocol: TCP
	    port: 8200
	---
	apiVersion: v1
	kind: Endpoints
	metadata:
	  name: external-vault
	subsets:
	  - addresses:
	      - ip: $EXTERNAL_VAULT_ADDR	    
	  - ports:
	      - port: 8200
	EOF
	
	$ > kubectl apply --filename external-vault.yaml
	service/external-vault created
	endpoints/external-vault created
	```

### Install the Vault Helm chart configured to address an external Vault

The Vault Helm chart can deploy only the Vault Agent Injector service configured to target an external Vault. The injector service enables the authentication and secret retrieval for the applications, by adding Vault Agent containers as they are written to the pod automatically it includes specific annotations.

Install the Vault Helm chart to run only the injector service, configure Vault's Kubernetes authentication, create a role to access a secret, and patch a deployment.

#### Install the Vault Helm chart

```
$ > helm repo add hashicorp https://helm.releases.hashicorp.com
$ > helm repo update
$ > helm install vault hashicorp/vault --set "injector.externalVaultAddr=http://external-vault:8200"
NAME: vault
LAST DEPLOYED: Mon Mar 20 16:14:13 2023
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Thank you for installing HashiCorp Vault!

Now that you have deployed Vault, you should look over the docs on using
Vault with Kubernetes available here:

https://www.vaultproject.io/docs/


Your release is named vault. To learn more about the release, try:

  $ helm status vault
  $ helm get manifest vault
```
The  `injector.externalVaultAddr`  is assigned the address of the Kubernetes service defined in the 

