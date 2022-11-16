![enter image description here](best.png)

## Kubernetes Best Practices

 - Base your images on well known trusted images to prevent supply chain attacks.
 - You should treat your image tag as immutable. Name your images with some combination of the semantic version and the SHA hash of the commit.
 - Run your application with at least two replicas to maintain HA.
 - Limit the scope of access for developers to just the namespace they require to develop in. This will limit the chance that a developer could accidentally delete resources in another namespace. 
 
**Limiting access to namespaces**

1. First add the user or group to the namespace you would like the user or group to have access to. Ensure you only select *Read Only* privileges.
![enter image description here](user.png)

2. Then, in the cluster you want to give the user or group access to a namespace, apply the following RoleBinding to give edit privileges to the namespace.

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

 

