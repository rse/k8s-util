
k8s-util &mdash; Kubernetes (K8S) Utility
=========================================

About
-----

This is a small utility for simplifying the management of access to a
[Kubernetes (K8S)](https://kubernetes.io) cluster from an arbitrary
GNU/Linux (x64) system. In particular, it allows you to...

- establish local a **docker(1)** and **docker-compose(1)** based Docker client environment,
  because developing and testing applications is usually done on just Docker.

- establish a **kubectl(1)**, **kubensx(1)** and **helm(1)** based Kubernetes client environment,
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

As a consequence, when developing and deploying in a Kubernetes
environment, those four client programs and their configurations are
essential. This is what **k8s-util(1)** deals with.

Installation
------------

```
$ git clone https://github.com/rse/k8s-util
$ make install [DESTDIR=/path] [PREFIX=/path]
```

NOTICE: **k8s-util(1)** requires
[bash(1)](https://www.gnu.org/software/bash/)),
[curl(1)](https://curl.haxx.se/) under run-time. The additionally
required tools docker(1), docker-compose(1), kubensx(1), kubectl(1), helm(1) and
jq(1) are automatically downloaded into `$HOME/.k8s-util/bin/` if
requested by the `env-docker` or `env-k8s` commands.

Usage
-----

### Establish Docker Client Environment

To establish your local Docker client environment, use:

  - For local access (via `/var/run/docker.sock`):

    ```sh
    $ eval `k8s-util env-docker`
    ```

  - For remote access (via HTTP):

    ```sh
    $ eval `k8s-util env-docker <hostname> tcp`
    ```

  - For remote access (via HTTPS):

    ```sh
    $ eval `k8s-util env-docker <hostname> tls`
    $ cp <path-to-ca-cert>     $DOCKER_CERT_PATH/ca.pem
    $ cp <path-to-client-cert> $DOCKER_CERT_PATH/cert.pem
    $ cp <path-to-client-key>  $DOCKER_CERT_PATH/key.pem
    ```

  - For remote access in [msg Project Server (PS)](https://ps.msg.team/) contexts
    (this requires SSH access to the server to automatically
    download the certificate/key files):

    ```sh
    $ eval `k8s-util env-docker <hostname> ps`
    ```

NOTICE: the `k8s-util env-docker` output has to be `eval`uated from
within GNU Bash, because the command augments your shell environment
with additional environment variables.

### Establish Kubernetes Client Environment

To establish your local Kubernetes environment, use:

  - For standard contexts (via existing `~/.kube/config`):

    ```sh
    $ eval `k8s-util env-k8s`
    ```

  - For custom contexts (via custom Kubernetes access configuration file):

    ```sh
    $ eval `k8s-util env-k8s <kubeconfig-file>`
    ```

  - For [msg Project Server (PS)](https://ps.msg.team/) contexts (where `<hostname>` is the
    hostname of the msg Project Server instance) where the K3S
    Kubernetes stack (`ase-k3s`) was installed with `docker-stack
    install ase-k3s` beforehand and `<username>` can be either the
    K8S-external user `admin` or the K8S-internal user `root`:

    ```sh
    $ eval `k8s-util env-kubernetes <hostname> [<username>]`
    ```

NOTICE: the `k8s-util env-k8s` output has to be `eval`uated from
within GNU Bash, because the command augments your shell environment
with additional environment variables.

### Create Cluster Administration Service Account

To create an internal Kubernetes cluster administrator service account, use:

  - For regular Kubernetes contexts:

    ```
    $ k8s-util cluster-admin kube-system root create
    $ k8s-util kubeconfig kube-system root root >~/.kubeconfig-root
    ```

  - For [msg Project Server (PS)](https://ps.msg.team/) contexts where
    the K3S Kubernetes stack (`ase-k3s`) was installed with `docker-stack
    install ase-k3s` beforehand, the `root` service account is already
    pre-established and you just have to execute:

    ```
    $ k8s-util kubeconfig kube-system root root >~/.kubeconfig-root
    ```

### Create Custom Namespace

To create a custom namespace `sample` and corresponding namespace
administration service account `sample` in order to deploy an
application into it later, use:

```
$ k8s-util namespace sample create
$ k8s-util namespace-admin sample sample create
$ k8s-util kubeconfig sample sample sample >~/.kubeconfig-sample
```

### Generate KUBECONFIG Configurations

To access the Kubernetes cluster through one or more particular
service accounts, assemble the `$KUBECONFIG` configurations with:

```
$ k8s-util kubeconfig-stub >~/.kubeconfig-stub.yaml
$ k8s-util kubeconfig kube-system root root >~/.kubeconfig-root.yaml
$ k8s-util kubeconfig sample sample sample >~/.kubeconfig-sample.yaml
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

