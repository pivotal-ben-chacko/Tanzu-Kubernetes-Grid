
![Harbor logo](computer.jpg)

# Harbor

Harbor is an open source registry that secures artifacts with policies and role-based access control, ensures images are scanned and free from vulnerabilities, and signs images as trusted.

## Configuring HTTPS

By default, Harbor does not ship with certificates. It is possible to deploy Harbor without security, so that you can connect to it over HTTP. However, using HTTP is acceptable only in air-gapped test or development environments that do not have a connection to the external internet. Using HTTP in environments that are not air-gapped exposes you to man-in-the-middle attacks. In production environments, always use HTTPS. If you enable Content Trust with Notary to properly sign all images, you must use HTTPS.

To configure HTTPS, you must create SSL certificates. You can use certificates that are signed by a trusted third-party CA, or you can use self-signed certificates. This section describes how to use [OpenSSL](https://www.openssl.org/) to create a CA, and how to use your CA to sign a server certificate and a client certificate. You can use other CA providers, for example [Let’s Encrypt](https://letsencrypt.org/).

## Generate a Certificate Authority Certificate

Instructions on how to generate and deploy self-signed certificates, is well documented in the official Harbor documentation under [Configure HTTPS Access to Harbor](https://goharbor.io/docs/2.6.0/install-config/configure-https/). What is not well documented is how to provide your own signing certificate which Harbor will then use to generate leaf certificates with. There are many reasons why one might want to go this route, some of these might include:

 1. The certificate is trusted throughout the organization
 2. Browsers managed by the organization will trust the TLS certificate presented by Harbor and therefor not complain it is insecure.
 3. If the private key that signed the TLS certificate has in any way been compromised, then the security team can revoke the certificate. 

When deploying harbor we can provide the name of the TLS secret to secure HTTPS traffic with in the values file, but this means we, as the operator, are responsible for renewing the certificate before it expires at some point.  The better option would be to let [cert-manager](https://cert-manager.io/) do this job for us.

The way to accomplish this is by using either Issuers or ClusterIssuers. These are resources that represent certificate authorities (CAs) that are able to generate signed certificates by honoring certificate signing requests. All cert-manager certificates require a referenced issuer that is in a ready condition to attempt to honor the request.

Issuer example
```sh 
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: ca-issuer
  namespace: mesh-system
spec:
  ca:
  secretName: ca-key-pair
```
This is a simple `Issuer` that will sign certificates based on a private key. The certificate stored in the secret `ca-key-pair` can then be used to trust newly signed certificates by this `Issuer` in a Public Key Infrastructure (PKI) system.
