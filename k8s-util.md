
# k8s-util(1) -- Kubernetes (K8S) Utility

## SYNOPSIS

`k8s-util setup`

`k8s-util configure-docker` url \[*docker-url*\]

`k8s-util configure-docker` ca \[`-`|*ca-certificate-pem-file*\]

`k8s-util configure-docker` cert \[`-`|*client-certificate-pem-file*\]

`k8s-util configure-docker` key \[`-`|*client-key-pem-file*\]

`k8s-util configure-k8s` `default`|*kubeconfig-name* `-`|*kubeconfig-file*

`source <(k8s-util env)`

`k8s-util` \[`-v`\] `namespace` *namespace* `create`|`delete`

`k8s-util` \[`-v`\] `cluster-admin` *namespace* *account* `create`|`delete`

`k8s-util` \[`-v`\] `namespace-admin` *namespace* *account* `create`|`delete`

`k8s-util` \[`-v`\] `kubeconfig` [*namespace* *account* *context*]

`k8s-util cleanup`

## DESCRIPTION

This is a small utility for simplifying the management of access to
a Kubernetes (K8S) cluster from an arbitrary GNU/Linux system. In
particular, it allows you to...

- establish local a **docker(1)** and **docker-compose(1)** based *Docker* client
  environment, because developing and testing applications is usually done
  on just *Docker*.

- establish a **kubensx(1)**, **kubectl(1)** and **helm(1)** based *Kubernetes* client
  environment, because running applications finally requires access to a
  *Kubernetes* cluster.

- create/delete cluster administrator service account, because most
  *Kubernetes* clusters initially just provide an externally managed
  administrator account for bootstrapping, but *Kubernetes Dashboard* and
  other contexts require a true internally managed administrator account.

- create/delete a custom namespace and create/delete namespace
  administrator service account, because applications should be deployed
  into their own dedicated *Kubernetes* namespace.

- generate the `$KUBECONFIG` configurations for using service accounts,
  because **kubectl(1)** and **helm(1)** require those standardized access
  configurations.

## HISTORY

The `k8s-util`(1) utility was developed between August 2019 and January
2020 for being able to easily manage access to a Kubernetes cluster.

## AUTHOR

Dr. Ralf S. Engelschall <rse@engelschall.com>

