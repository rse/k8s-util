
k8s-util &mdash; Kubernetes (K8S) Utility
=========================================

About
-----

This is a small GNU bash based utility for simplifying the management of
access to a [Kubernetes (K8S)](https//kubernetes.io) cluster. It allows
you to create/delete a custom namespace, create/delete namespace/cluster
administrator service accounts and generate the `$KUBECONFIG` YAML
snippets for using those service accounts. This is handy because the
initial bootstrapping of Kubernetes access (to the cluster or just a
namespace) is a standard task and especially should not be part of any
Helm chart.

Installation
------------

```
$ curl -L -o k8s-util https://raw.githubusercontent.com/rse/k8s-util/master/k8s-util.bash && \
  chmod 755 k8s-util
```

Usage
-----

Create a cluster administration service account `root`:

```
$ k8s-util cluster-admin kube-system root create
$ k8s-util kubeconfig kube-system root root >~/.kubeconfig-root
$ KUBECONFIG=~/.kubeconfig-root kubectl version
```

Create a namespace `sample` and corresponding namespace administration service account `sample`:

```
$ k8s-util namespace sample create
$ k8s-util namespace-admin sample sample create
$ k8s-util kubeconfig sample sample sample >.kubeconfig-sample
$ KUBECONFIG=~/.kubeconfig-sample kubectl version
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

