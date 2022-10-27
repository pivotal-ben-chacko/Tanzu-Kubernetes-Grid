
![traefik logo](traefik.jpeg)


#### Install Graylog OVA Appliance
1. Import OVA template into vsphere
2. Start VM and note the username and password by launching the web console
3. Navigate to VM IP address and enter credentials from step 2 
4. Go to **System/Inputs** from the GUI and select **Inputs** 
5. Select **GELF TCP** from the drop-down and click on **Launch new input**

*Run the following command to test Graylog input. If installed correctly. the test message will show up in Graylog logging*
```bash
# Replace GRAYLOG-SERVER-IP with ip of Graylog server
echo -e '{"version": "1.1","host":"skynetsystems.io","short_message":"Short message","full_message":"Backtrace here\n\nmore stuff","level":1,"_user_id":9001,"_some_info":"foo","_some_env_var":"bar"}\0' | nc -w 1 <GRAYLOG-SERVER-IP> 12201
```


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

* Fluentbit Graylog config: [https://docs.fluentbit.io/manual/pipeline/outputs/gelf](https://docs.fluentbit.io/manual/pipeline/outputs/gelf)

* Graylog VM Install: [https://graylog2zh-cn.readthedocs.io/zh_CN/latest/pages/installation/virtual_machine_appliances.html](https://graylog2zh-cn.readthedocs.io/zh_CN/latest/pages/installation/virtual_machine_appliances.html)

* Graylog OVA appliance: [https://github.com/Graylog2/graylog2-images](https://github.com/Graylog2/graylog2-images)


