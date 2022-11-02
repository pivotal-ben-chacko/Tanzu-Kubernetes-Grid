![rabbitmq logo](rabbitmq.jpeg)

### RabbitMQ packaged by Bitnami
RabbitMQ is an open source general-purpose message broker that is designed for consistent, highly-available messaging scenarios (both synchronous and asynchronous).

**Installing RabbitMQ**

Use Helm to install the package. Ensure you have already created the rabbitmq namespace for the package to install to.
```bash
helm repo add my-repo https://charts.bitnami.com/bitnami
helm repo update
helm install rabbitmq bitnami/rabbitmq -n rabbitmq
```

**Enabling TLS**

The process of generating a Certificate Authority and two key pairs is fairly labourious and can be error-prone. An easier way of generating all that stuff on MacOS or Linux is with [tls-gen](https://github.com/rabbitmq/tls-gen): it requires Python 3.5+, make and openssl in PATH.

```bash
git clone https://github.com/rabbitmq/tls-gen tls-gen
cd tls-gen/basic
make
make verify
make info
```

- The TLS certificates/keys should now be available in */results* folder.

Execute the following command to create the secret, replacing the example paths shown with the correct paths to your certificates:

```bash
kubectl create secret generic rabbitmq-certificates --from-file=./ca.crt --from-file=./tls.crt --from-file=./tls.key -n rabbitmq
```

**Retrieve values file for Helm release** 

Now that we have the secret created, we can update the chart to use that secret for TLS.

```bash
helm get values rabbitmq -n rabbitmq --all > values.yaml
vim values.yaml
# update the following values in values.yaml
 
      tls.enabled=true
      tls.existingSecret=rabbitmq-certificates

# update the rabbitmq helm release by injecting the new values
helm upgrade --install rabbitmq bitnami/rabbitmq -n rabbitmq --values values.yaml
```

**Verify TLS**

To verify TLS is working we can run the following openssl command. This command will indicate a failure and disconnect since we are using a self signed certificate but the output should still show our server certificate, otherwise openssl should stay connected to the server
```bash
openssl s_client -connect skynetsystems.io:5671 -verify_quiet
```
