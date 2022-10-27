
![traefik logo](traefik.jpeg)


#### Install Graylog OVA Appliance
1. Import OVA template into vsphere
2. Start VM and note the username and password by launching the web console
3. Navigate to VM IP address and enter credentials from step 2 


#### Install FluentBit
```bash
# install FluentBit in k8s cluster
git clone https://github.com/pivotal-ben-chacko/Tanzu-Kubernetes-Grid.git
cd Tanzu-Kubernetes-Grid/graylog
tanzu package install fluent-bit --package-name fluent-bit.tanzu.vmware.com --version 1.8.15+vmware.1-tkg.1 --values-file fluent-bit-data-values.yaml --namespace tanzu-packages

# verify FluentBit is installed and running
kubectl get all -n tanzu-system-logging
NAME                   READY   STATUS    RESTARTS   AGE
pod/fluent-bit-2h96b   1/1     Running   0          3h10m
pod/fluent-bit-5n9pj   1/1     Running   0          3h10m
pod/fluent-bit-fbfkx   1/1     Running   0          3h10m
pod/fluent-bit-fvt6r   1/1     Running   0          3h10m
pod/fluent-bit-gtfmh   1/1     Running   0          3h10m
pod/fluent-bit-rs9xt   1/1     Running   0          3h10m
pod/fluent-bit-xq8bp   1/1     Running   0          3h10m
```
</br>

#### Links

* Fluentbit Graylog config: [https://docs.fluentbit.io/manual/pipeline/outputs/gelf](https://gitlab.com/nanuchi/argocd-app-config)

* Graylog VM Install: [hhttps://graylog2zh-cn.readthedocs.io/zh_CN/latest/pages/installation/virtual_machine_appliances.html](https://hub.docker.com/repository/docker/nanajanashia/argocd-app)

* Graylog OVA appliance: [https://github.com/Graylog2/graylog2-images](https://argo-cd.readthedocs.io/en/stable/getting_started/#1-install-argo-cd)


