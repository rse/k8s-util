
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
[bash(1)](https://www.gnu.org/software/bash/) and
[curl(1)](https://curl.haxx.se/) under run-time. The additionally
required tools docker(1), docker-compose(1), kubensx(1), kubectl(1), helm(1) and
jq(1) are automatically downloaded into `$HOME/.k8s-util/bin/` when
the `k8s-util setup` command is executed.

Usage
-----

### Setup or Cleanup Client Environment

To establish your local client environment, use:

```sh
$ k8s-util setup
```

For later removing the local client environment again, use:

```sh
$ k8s-util cleanup
```

By default the environment is located in `$HOME/.k8s-util.d`.
You can override this with the environment variable `$K8S_UTIL_BASEDIR`.

### Configure Docker Access

To configure your Docker access, use:

  - For local access (via `/var/run/docker.sock`):

    (just do nothing, this is the default)

  - For remote access (via HTTP):

    ```sh
    $ k8s-util configure-docker url tcp://<hostname>:2375
    ```

  - For remote access (via HTTPS):

    ```sh
    $ k8s-util configure-docker url tcp://<hostname>:2376
    $ k8s-util configure-docker ca   <path-to-ca-cert>
    $ k8s-util configure-docker cert <path-to-client-cert>
    $ k8s-util configure-docker key  <path-to-client-key>
    ```

### Configure Kubernetes Access

To configure your Kubernetes access, use:

  - For standard contexts (via existing `~/.kube/config`):

    ```sh
    $ k8s-util configure-k8s default ~/.kube/config
    ```

  - For custom contexts (via custom Kubernetes access configuration file):

    ```sh
    $ k8s-util configure-k8s default <kubeconfig-file>
    ```

  - For using multiple contexts:

    ```sh
    $ k8s-util kubeconfig | k8s-util configure-k8s default -
    $ k8s-util configure-k8s <user-1> <kubeconfig-file-1>
    $ k8s-util configure-k8s <user-2> <kubeconfig-file-2>
    $ k8s-util configure-k8s <user-3> <kubeconfig-file-3>
    $ kubectl context use-context root
    $ kubectl -o yaml version
    $ kubectl get nodes
    $ kubectl -n kube-system get all
    $ kubectl --context sample get all
    ```

### Provide Shell Environment

In order to use the established local environment, use:

```sh
$ source <(k8s-util env)
```

### Create Cluster Administration Service Account

To create an internal Kubernetes cluster administrator service account, use:

```
$ k8s-util cluster-admin kube-system root create
$ k8s-util kubeconfig kube-system root root | k8s-util configure-k8s root -
```

### Create Custom Namespace

To create a custom namespace `sample` and corresponding namespace
administration service account `sample` in order to deploy an
application into it later, use:

```
$ k8s-util namespace sample create
$ k8s-util namespace-admin sample sample create
$ k8s-util kubeconfig sample sample sample | k8s-util configure-k8s sample -
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

