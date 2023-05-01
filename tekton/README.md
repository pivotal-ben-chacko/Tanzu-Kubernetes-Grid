![tekton](tekton.png)
## Tekton pipeline using Docker in Docker	

### Running tests inside a Docker container

The following pipeline will clone a repository from Github and run unit tests from within a docker container. This is called Docker in Docker, which allows you to run a Docker daemon within a Docker container. Technically this is quite tricky and there seems to be some issues with this approach, especially because you have to run this container in privileged mode.

**There are a couple ways you can run Docker in Docker**
-   Launching a Docker container inside a Docker container
-   Sharing the Docker daemon with the host machine and increasing the number of containers in the same hierarchy as the host environment. 

### Example 1: Docker in Docker Using dind

This method uses a container with Docker installed and runs a Docker daemon in the container separately from the host. Alpine based  [Docker official image](https://hub.docker.com/_/docker/)  and ubuntu based  [teracy/ubuntu](https://hub.docker.com/_/docker/)  are available as images for DinD. (dind tag) based on alpine, and  [teracy/ubuntu](https://github.com/teracyhq/docker-files/tree/master/ubuntu)  based on ubuntu.

The following is an example of the command for Docker-in-Docker using the official Docker image  `docker:stable-dind`.

```shell
$ docker run --privileged --name dind -d docker:stable-dind
$ docker exec -it dind /bin/ash
```

### Example 2: Docker in Docker Using [/var/run/docker.sock]

This method does not use a Docker-in-Docker image; it uses the Docker daemon on the host machine from a Docker container.

 This method is sometimes called DooD (Docker outside of Docker). Since it only mounts the socket of the host environment, the Docker image to be used is not  `dind`, and the -privileged option is not required. To be more specific, just run the following command:

```
$ docker run -ti --rm -v /var/run/docker.sock:/var/run/docker.sock docker /bin/ash
```

For more information about Tekton pipelines see: [Tekton Docs](https://tekton.dev/docs/)

**Example Tekton pipeline using Docker in Docker:**
```apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: run-tests
  description: Run Tests
spec:
  workspaces:
    - name: source
  steps:
    - name: read
      image: eclipse-temurin:17.0.3_7-jdk-alpine
      workingDir: $(workspaces.source.path)
      script: |-
              cd `mktemp -d`
              apk update | apk add git
              git clone https://github.com/testcontainers/testcontainers-java-repro.git
              cd testcontainers-java-repro
              ./mvnw test
      volumeMounts:
        - mountPath: /var/run/
          name: dind-socket
  sidecars:
    - image: docker:20.10-dind
      name: docker
      securityContext:
        privileged: true
      volumeMounts:
        - mountPath: /var/lib/docker
          name: dind-storage
        - mountPath: /var/run/
          name: dind-socket
  volumes:
    - name: dind-storage
      emptyDir: { }
    - name: dind-socket
      emptyDir: { }
---
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: testcontainers-demo
spec:
  description: |
    This pipeline clones a git repo, run testcontainers.
  params:
    - name: repo-url
      type: string
      description: The git repo URL to clone from.
  workspaces:
    - name: shared-data
      description: |
        This workspace contains the cloned repo files, so they can be read by the
        next task.
  tasks:
    - name: run-tests
      taskRef:
        name: run-tests
      workspaces:
        - name: source
          workspace: shared-data
---
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: testcontainers-demo-run
spec:
  pipelineRef:
    name: testcontainers-demo
  workspaces:
    - name: shared-data
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 1Gi
  params:
    - name: repo-url
      value: https://github.com/testcontainers/testcontainers-java-repro.git
```
