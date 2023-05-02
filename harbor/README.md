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

The way to accomplish this is by using either [Issuers](https://cert-manager.io/docs/concepts/issuer/) or [ClusterIssuers](https://cert-manager.io/docs/concepts/issuer/). These are resources that represent certificate authorities (CAs) that are able to generate signed certificates by honoring certificate signing requests. All cert-manager certificates require a referenced issuer that is in a ready condition to attempt to honor the request.

Issuer example
```sh 
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: ca-issuer
  namespace: mesh-system
spec:
  ca:
  secretName: harbor-ca-key-pair
```
This is a simple `Issuer` that will sign certificates based on a private key. The certificate stored in the secret `ca-key-pair` can then be used to trust newly signed certificates by this `Issuer` in a Public Key Infrastructure (PKI) system.

## Replace Harbor signing CA with your own

1. First let's create a secret in the *tanzu-system-registry* namespace that will store your signing CA and private key. Remember to base64 encode your CA and key and insert in the appropriate locations below.

    ```sh
    apiVersion: v1
    kind: Secret
    metadata:
      name: harbor-ca-key-pair
      namespace: tanzu-system-registry
    type: kubernetes.io/tls
    data:
      tls.crt: LS0tLS1CRU....
      tls.key: LS0tLS1CRU....
    ```
2. Next we need create the Issuer and reference the secret that we created in the step above.

    ```sh
    apiVersion: cert-manager.io/v1
    kind: Issuer
    metadata:
      name: harbor-ca-issuer
      namespace: tanzu-system-registry
    spec:
      ca:
        secretName: harbor-ca-key-pair
    ```

3. Once applied, ensure that the issuer has a status of *True* under the column *Ready*.

    ```sh
    k get issuer -n tanzu-system-registry
    NAME        		READY   AGE
    harbor-ca-key-pair	True    39h
    ```
4. Next we will create the TLS certificate by utilizing the Issuer we created in step 2. This will ensure that the TLS certificate is generated using our custom signing key and on top of that the TLS certificate will be managed by [cert-manager](https://cert-manager.io). This will ensure that the TLS key is renewed before it's expiry automatically by cert-manager. 

    ```sh
    apiVersion: cert-manager.io/v1
    kind: Certificate
    metadata:
      name: harbor-tls
      namespace: tanzu-system-registry
    spec:
      secretName: harbor-tls-secret
      dnsNames:
      - "harbor.skynetsystems.io"
      issuerRef:
        name: harbor-ca-issuer
        # We can reference ClusterIssuers by changing the kind here.
        # The default value is Issuer (i.e. a locally namespaced Issuer)
        kind: Issuer
    ```
    Ensure that the secret has been created and that you see 3 as the number of data items in the secret:
    
    ```sh
    kubectl get secret harbor-tls-secret -n tanzu-system-registry
    NAME                TYPE                DATA   AGE
    harbor-tls-secret   kubernetes.io/tls   3      58s
    ```

    You can view the TLS certificate in the secret by running:
    
    ```sh
    $ > kubectl get secret harbor-tls-secret -n tanzu-system-registry -o json | jq -r '."data" ."tls.crt"' | base64 -d
    
    -----BEGIN CERTIFICATE-----
    MIIDCzCCAfOgAwIBAgIRAJtO3JvlDmFVRC5V3WqQs3kwDQYJKoZIhvcNAQELBQAw
    GDEWMBQGA1UEAwwNMTkyLjE2OC4yLjEwNzAeFw0yMjExMTAxNTM3NDdaFw0yMzAy
    MDgxNTM3NDdaMAAwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDB2Sxg
    DSYwQifh1iAN2w64ZMBTEdr1O3QSudYPPgEIE6kETrUd8zSFvNf9Olhaf59T0Z74
    puFa/W70VZ28csVuc9+8Wb3hv/96Ab3LlCyWMH6q/9Ol7PTo24k2UYIckgYXGG1k
    phq1d2XJvOIHBATnGkuGG0Km4NSm5SJ7D1EJuqTCEXkhE2fi/17kIJPOsvMVqVx0
    DKQCPRHrr+KmOUA7kT0RPafEzxCZ7TNJqVcSn4+iS5WLRwjQugT7+rnYYfS4fDtI
    E87zNrm4Znqs378rXk0WoV7ffrcahCQT2WalDpKnlUqk5+otMyew/M7DYV29y6rI
    bb25v/3Lw40TzGMhAgMBAAGjaDBmMA4GA1UdDwEB/wQEAwIFoDAMBgNVHRMBAf8E
    AjAAMB8GA1UdIwQYMBaAFLhft7CYG/noqJirgUmim+QpFmmUMCUGA1UdEQEB/wQb
    MBmCF2hhcmJvci5za3luZXRzeXN0ZW1zLmlvMA0GCSqGSIb3DQEBCwUAA4IBAQBW
    xSk4cnqH5n9snQ+zF1Z64+Ey3dY5X7lRQl5DmPRcPvfFHXm3rcv3YquT7tCzIVno
    c9+4lA4AdgoPCBocPgE9VUeV3JZMbOCI4BqeGrP57mm7BU9xZxTUgwWGnJk2l9wC
    xwyAfsS5pc4HCgp6w62prVXi6qEPxIvcXMDZGi35BbklAAwgWa3Lj2Gvam7Z/JKC
    diILj8+daCnxXx8+eb74WzF6XNndMWP0jgVpmGtOu9bnpuKZDTuRQA9t6WFg/S0/
    2UKGs2ye2P2Jodizv4mmlPM4JFLMjqzRbz09715OB1KExsGxZDWnxNuWbFsOPbkT
    4s5KJwYMH511EMtXwudp
    -----END CERTIFICATE-----
    ```

   We should also see annotations in the secret that show the secret is managed by cert-manager
    
    ```sh
    kubectl get secret harbor-tls-secret -n tanzu-system-registry -o json | jq -r '.metadata .annotations'
    {
      "cert-manager.io/alt-names": "harbor.skynetsystems.io",
      "cert-manager.io/certificate-name": "harbor-tls",
      "cert-manager.io/common-name": "",
      "cert-manager.io/ip-sans": "",
      "cert-manager.io/issuer-group": "",
      "cert-manager.io/issuer-kind": "Issuer",
      "cert-manager.io/issuer-name": "ca-issuer",
      "cert-manager.io/uri-sans": ""
    }
    ```

5. Finally we need to tell harbor to use use this TLS key pair that is managed by cert-manager. To do this we update the following property in the values.yaml file to: 

    ```sh
    tlsCertificateSecretName: harbor-tls-secret
    ```
    
    where *harbor-tls-secret* is the name of the secret that contains the TLS key pair we generated in step 4.

    Once the values.yaml file is updated, you can proceed to install Harbor using the Tanzu CLI or update an existing Harbor installation injecting the updated values.yaml file into the deployment.

