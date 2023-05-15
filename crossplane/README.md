![crossplane](crossplane.png)
![crossplane](crossplane.png)

## Control Planes of the Future

Crossplane is an open source control plane framework supported by the cloud-native community.

The cloud vendors have been building with control planes for years. Now Crossplane helps you do the same. Control planes are self-healing—they automatically correct drift. Consumers can self-service fast because control planes offer a single point of control for policy and permissions and control planes integrate easily with other systems because they expose an API, not just a command-line.

### Why use Crossplane



**Declarative configuration**: Crossplane lets you build a control plane with Kubernetes-style declarative and API-driven configuration and management for anything. Through this approach, applications and infrastructure managed through your control plane are self-healing right out of the box.

**One source of truth**: Control planes built with Crossplane integrate with CI/CD pipelines, so teams can create, track, and approve changes using GitOps best practices.

**Unify application and infrastructure configuration and deployment**: Crossplane enables application and infrastructure configuration to co-exist in the same control plane, reducing the complexity of your toolchains and deployment pipelines.

**Automate operational tasks with reconciling controllers**: Your control planes are made up of several controllers, which are responsible for the entire lifecycle of a resource. Each resource is responsible for provisioning, health, scaling, failover, and actively responding to external changes that deviate from the desired configuration.

## Azure Quickstart

Connect Crossplane to Microsoft Azure to create and manage cloud resources from Kubernetes with the [Upbound Azure Provider](https://marketplace.upbound.io/providers/upbound/provider-azure).


**Step 1**: Install the Azure Provider

```
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: upbound-provider-azure
spec:
  package: xpkg.upbound.io/upbound/provider-azure:v0.29.0
EOF
```


**Step 2**: Install the Azure command-line Generating an  [authentication file](https://docs.microsoft.com/en-us/azure/developer/go/azure-sdk-authorization#use-file-based-authentication)  requires the Azure command-line. Follow the documentation from Microsoft to  [Download and install the Azure command-line](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli).

Log in to the Azure command-line.

```
az login # follow the prompts
```

**Step 3**: Create an Azure service principal
