
k8s-util &mdash; Kubernetes (K8S) Utility
=========================================

About
-----

This is a small [GNU Bash](https://www.gnu.org/software/bash/) based
utility for simplifying the management of access to a [Kubernetes
(K8S)](https://kubernetes.io) cluster from an arbitrary GNU/Linux
system. In particular, it allows you to...

- establish local a **docker(1)** and **docker-compose(1)** based Docker client environment,
  because developing and testing applications is usually done on just Docker.

- establish a **kubectl(1)** and **helm(1)** based Kubernetes client environment,
  because running applications finally requires access to a Kubernetes cluster.

- create/delete cluster administrator service account,
  because most Kubernetes clusters initially just provide an externally
  managed administrator account for bootstrapping, but Kubernetes Dashboard and other
  contexts require a true internally managed administrator account.

- create/delete a custom namespace and
  create/delete namespace administrator service account,
  because applications should be deployed into their own dedicated Kubernetes namespace.

- generate the `$KUBECONFIG` configurations for using service accounts,
  because **kubectl(1)** and **helm(1)** require those standardized access configurations.

Short Background
----------------

On the application development side, the Docker and Kubernetes worlds
are primarily driven by four command-line client programs:

|            | low-level<br/>(commands) | high-level<br/>(stacks) |
|----------- | ------------------------ | ----------------------- |
| Docker     | **docker(1)**            | **docker-compose(1)**   |
| Kubernetes | **kubectl(1)**           | **helm(1)**             |

Installation
------------

```
$ git clone https://github.com/rse/k8s-util
$ source k8s-util/k8s-util.bash
```

Usage
-----

### Establish Docker Client Environment

To establish your local Docker environment use:

  - For local contexts (via `/var/run/docker.sock`):

    ```sh
    $ k8s-util env-docker
    ```

  - For remote contexts (via HTTP):

    ```sh
    $ k8s-util env-docker <hostname> tcp
    ```

  - For remote contexts (via HTTPS):

    ```sh
    $ k8s-util env-docker <hostname> tls
    $ cp <path-to-ca-cert>     $DOCKER_CERT_PATH/ca.pem
    $ cp <path-to-client-cert> $DOCKER_CERT_PATH/cert.pem
    $ cp <path-to-client-key>  $DOCKER_CERT_PATH/key.pem
    ```

  - For remote msg Project Server (PS) contexts:

    ```sh
    $ k8s-util env-docker <hostname> ps
    ```

### Establish Kubernetes Client Environment

To establish your local Kubernetes environment use:

  - For standard contexts (via existing `~/.kube/config`):

    ```sh
    $ k8s-util env-k8s
    ```

  - For custom contexts (via custom Kubernetes access configuration):

    ```sh
    $ k8s-util env-k8s <kubeconfig-file>
    ```

  - For msg Project Server (PS) contexts (where `<hostname>` is the
    hostname of the msg Project Server instance) where the K3S Kubernetes
    stack was installed with `docker-stack install ase-k3s` beforehand
    and <username> can be either `admin` or `root`:

    ```sh
    $ k8s-util env-kubernetes <hostname> [<username> [<context>]]
    ```

### Create Cluster Administration Service Account

The `k8s-util.bash` script allows you to create
a true internal Kubernetes cluster administrator service account:

  - For regular Kubernetes contexts:

    ```
    $ k8s-util cluster-admin kube-system root create
    $ k8s-util kubeconfig kube-system root root >~/.kubeconfig-root
    ```

  - For msg Project Server (PS) contexts where the K3S Kubernetes stack was
    installed with `docker-stack install ase-k3s` beforehand, the `root`
    service account is already pre-established and you just have to execute:

    ```
    $ k8s-util kubeconfig kube-system root root >~/.kubeconfig-root
    ```

### Create Custom Namespace

Create a custom namespace `sample` and corresponding namespace
administration service account `sample` in order to deploy an
application into it later:

```
$ k8s-util namespace sample create
$ k8s-util namespace-admin sample sample create
$ k8s-util kubeconfig sample sample sample >~/.kubeconfig-sample
```

### Generate KUBECONFIG Configurations

In order to access the Kubernetes cluster through one or more particular
service accounts, assemble the `$KUBECONFIG` configurations:

```
$ k8s-util kubeconfig-stub >~/.kubeconfig-stub
$ k8s-util kubeconfig kube-system root root >~/.kubeconfig-root
$ k8s-util kubeconfig sample sample sample >~/.kubeconfig-sample
```

Then use them like this:

```
$ export KUBECONFIG=~/.kubeconfig-stub.yaml:~/.kubeconfig-root.yaml:~/.kubeconfig-sample.yaml
$ kubectl context use-context root
$ kubectl -o yaml version
$ kubectl get nodes
$ kubectl -n kube-system get all
$ kubectl --context sample get all
```

License
-------

Copyright &copy; 2019-2020 Dr. Ralf S. Engelschall (http://engelschall.com/)

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

