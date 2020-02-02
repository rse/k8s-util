##
##  k8s-util-env-kubernetes-ps.bash -- Kubernetes CLI provisioning (for ProjectServer contexts)
##  Copyright (c) 2019-2020 Dr. Ralf S. Engelschall <rse@engelschall.com>
##  Distributed under MIT license <https://spdx.org/licenses/MIT.html>
##
##  Usage:
##  | source k8s-util.bash
##  | k8s-util [...]
##

#   remember our base directory
k8s_util_basedir="$(cd $(dirname ${BASH_SOURCE}) && pwd)"

#   the k8s-util(1) top-level functionality
k8s_util () {
    #   show usage
    if [[ $# -eq 0 ]]; then
        my_usage () {
            echo "k8s-util: USAGE: bash ${BASH_SOURCE} $*" 1>&2
        }
        my_usage "env-docker     [<hostname> tcp|tls|ps]"
        my_usage "env-k8s        [<kubeconfig-file> | <hostname> [<username> [<context>]]]"
        my_usage "namespace       <namespace> create|delete"
        my_usage "cluster-admin   <namespace> <account> create|delete"
        my_usage "namespace-admin <namespace> <account> create|delete"
        my_usage "kubeconfig     [<namespace> <account> <context>]"
        return 1
    fi

    #   dispatch commands
    if [[ $1 == "env-docker" ]]; then
        shift
        source $k8s_util_basedir/k8s-util-env-docker.bash ${1+"$@"}
    elif [[ $1 == "env-k8s" ]]; then
        shift
        source $k8s_util_basedir/k8s-util-env-k8s.bash ${1+"$@"}
    else
        $SHELL $k8s_util_basedir/k8s-util-cfg.bash ${1+"$@"}
    fi
}

#   the k8s-util(1) shell entry
alias k8s-util=k8s_util

