#!/bin/bash
##
##  k8s-util.bash -- Kubernetes (K8S) Utility
##  Copyright (c) 2019-2020 Dr. Ralf S. Engelschall <rse@engelschall.com>
##
##  Permission is hereby granted, free of charge, to any person obtaining
##  a copy of this software and associated documentation files (the
##  "Software"), to deal in the Software without restriction, including
##  without limitation the rights to use, copy, modify, merge, publish,
##  distribute, sublicense, and/or sell copies of the Software, and to
##  permit persons to whom the Software is furnished to do so, subject to
##  the following conditions:
##
##  The above copyright notice and this permission notice shall be included
##  in all copies or substantial portions of the Software.
##
##  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
##  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
##  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
##  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
##  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
##  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
##  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
##

#   display verbose message
verbose () {
    echo "k8s-util: $*" 1>&2
}

#   handle usage error
usage () {
    echo "k8s-util: ERROR: $1" 1>&2
    echo "k8s-util: USAGE: bash ${BASH_SOURCE} $2" 1>&2
    exit 1
}

#   handle fatal error
fatal () {
    echo "k8s-util: ERROR: $*" 1>&2
    exit 1
}

#   fetch configuration
conf () {
    #   determine expansion command
    local id="$1"
    shift
    local cmd="sed -e \"1,/%!${id}$/d\" -e \"/%!.*/,\\\$d\" -e \"s/^    //\""
    for arg in "$@"; do
        local var=$(echo "$arg" | sed -e 's;=.*$;;')
        local val=$(echo "$arg" | sed -e 's;^[^=]*=;;')
        cmd="$cmd -e \"s;{{${var}}};${val};g\""
    done

    #   generate YAML snippet
    #   (send to stdout and optionally show on stderr)
    (
        (
            eval "$cmd" <<'EOT'
    %!namespace
    ---
    #   create "{{ns}}" namespace
    apiVersion: v1
    kind: Namespace
    metadata:
        name: {{ns}}
        labels:
            name: {{ns}}

    %!cluster-admin
    ---
    #   create "{{sa}}" cluster service account
    apiVersion: v1
    kind: ServiceAccount
    metadata:
        namespace: {{ns}}
        name: {{sa}}
        labels:
            name: {{sa}}
    ---
    #   create full-access role for cluster service account "{{sa}}"
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRole
    metadata:
        namespace: {{ns}}
        name: {{sa}}-role
        labels:
            name: {{sa}}
    rules:
        -   apiGroups: [ "", "*" ]
            resources: [ "*" ]
            verbs: [ "*" ]
    ---
    #   bind full-access role to cluster service account "{{sa}}"
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
        namespace: {{ns}}
        name: {{sa}}-role-binding
        labels:
            name: {{sa}}
    subjects:
        -   kind: ServiceAccount
            namespace: {{ns}}
            name: {{sa}}
    roleRef:
        apiGroup: rbac.authorization.k8s.io
        kind: ClusterRole
        name: {{sa}}-role

    %!namespace-admin
    #   create "{{sa}}" service account in "{{ns}}" namespace
    apiVersion: v1
    kind: ServiceAccount
    metadata:
        namespace: {{ns}}
        name: {{sa}}
        labels:
            name: {{sa}}
    ---
    #   create full-access role for service account "{{sa}}" in "{{ns}}" namespace
    apiVersion: rbac.authorization.k8s.io/v1
    kind: Role
    metadata:
        namespace: {{ns}}
        name: {{sa}}-role
        labels:
            name: {{sa}}
    rules:
        -   apiGroups: [ "", "*" ]
            resources: [ "*" ]
            verbs: [ "*" ]
    ---
    #   bind full-access role to service account "{{sa}}" in "{{ns}}" namespace
    apiVersion: rbac.authorization.k8s.io/v1
    kind: RoleBinding
    metadata:
        namespace: {{ns}}
        name: {{sa}}-role-binding
        labels:
            name: {{sa}}
    subjects:
        -   kind: ServiceAccount
            namespace: {{ns}}
            name: {{sa}}
    roleRef:
        apiGroup: rbac.authorization.k8s.io
        kind: Role
        name: {{sa}}-role

    %!kubeconfig-stub
    ---
    apiVersion: v1
    kind: Config
    current-context:

    %!kubeconfig
    ---
    apiVersion: v1
    kind: Config
    current-context: {{context}}
    contexts:
        -   name: {{context}}
            context:
                cluster: {{cluster}}
                namespace: {{ns}}
                user: {{cluster}}-{{sa}}
    clusters:
        -   name: {{cluster}}
            cluster:
                server: {{server}}
    users:
        -   name: {{cluster}}-{{sa}}
            user:
                token: {{token}}
EOT
        ) | (
            if [[ $verbosity == true ]]; then
                tee /dev/stderr | sed -e "s;^;-- | ;"
            else
                cat 1>&2
            fi
        ) 3>&2 2>&1 1>&3
    )
}

#   create/delete namespace
cmd_namespace () {
    #   handle command-line arguments
    my_usage () {
        usage "$1" "namespace <namespace> create|delete"
    }
    if [[ $# -ne 2 ]]; then
        my_usage "invalid number of arguments"
    fi
    ns="$1"; cmd="$2"

    #   dispatch action according to command
    if [[ $cmd == "create" ]]; then
        verbose "create namespace \"$ns\""
        kubectl apply -f - < <(conf namespace ns="$ns")
    elif [[ $cmd == "delete" ]]; then
        verbose "delete namespace \"$ns\""
        kubectl delete -f - < <(conf namespace ns="$ns")
        verbose "await state to be settled"
	    kubectl wait --timeout=120s --for=delete "namespace/$ns" >/dev/null 2>&1 || true
    else
        my_usage "invalid command"
    fi
}

#   create/delete cluster admin service account
cmd_cluster_admin () {
    #   handle command-line arguments
    my_usage () {
        usage "$1" "cluster-admin <namespace> <account> create|delete"
    }
    if [[ $# -ne 3 ]]; then
        my_usage "invalid number of arguments"
    fi
    ns="$1"; sa="$2"; cmd="$3"

    #   dispatch action according to command
    if [[ $cmd == "create" ]]; then
        verbose "create cluster admin service account \"$sa\" in namespace \"$ns\""
        kubectl apply -f - < <(conf cluster-admin ns="$ns" sa="$sa")
        verbose "await state to be settled"
        while [[ $(kubectl -n "$ns" get -l name="$sa" sa -o jsonpath --template='{.items[].secrets[].name}') == "" ]]; do
            sleep 0.25
        done
    elif [[ $cmd == "delete" ]]; then
        verbose "delete cluster admin service account \"$sa\" in namespace \"$ns\""
        kubectl delete -f - < <(conf cluster-admin ns="$ns" sa="$sa")
        verbose "await state to be settled"
	    kubectl -n "$ns" wait --timeout=120s --for=delete "serviceaccount/$sa" >/dev/null 2>&1 || true
    else
        my_usage "invalid command"
    fi
}

#   create/delete namespace admin service account
cmd_namespace_admin () {
    #   handle command-line arguments
    my_usage () {
        usage "$1" "namespace-admin <namespace> <account> create|delete"
    }
    if [[ $# -ne 3 ]]; then
        my_usage "invalid number of arguments"
    fi
    ns="$1"; sa="$2"; cmd="$3"

    #   dispatch action according to command
    if [[ $cmd == "create" ]]; then
        verbose "create namespace admin service account \"$sa\" in namespace \"$ns\""
        kubectl apply -f - < <(conf namespace-admin ns="$ns" sa="$sa")
        verbose "await state to be settled"
        while [[ $(kubectl -n "$ns" get -l name="$sa" sa -o jsonpath --template='{.items[].secrets[].name}') == "" ]]; do
            sleep 0.25
        done
    elif [[ $cmd == "delete" ]]; then
        verbose "delete namespace admin service account \"$sa\" in namespace \"$ns\""
        kubectl delete -f - < <(conf namespace-admin ns="$ns" sa="$sa")
        verbose "await state to be settled"
	    kubectl -n "$ns" wait --timeout=120s --for=delete "serviceaccount/$sa" >/dev/null 2>&1 || true
    else
        my_usage "invalid command"
    fi
}

#   generate a K8S kubectl(1) configuration
cmd_kubeconfig () {
    #   handle command-line arguments
    my_usage () {
        usage "$1" "kubeconfig [<namespace> <account> <context>]"
    }
    if [[ $# -ne 0 && $# -ne 3 ]]; then
        my_usage "invalid number of arguments"
    fi
    ns="$1"; sa="$2"; context="$3"

    if [[ $# -eq 0 ]]; then
        #   generate a K8S kubectl(1) configuration stub
        #   (for just switching contexts)
        cat <(conf kubeconfig-stub)
    else
        #   determine K8S API service URL
        verbose "determine Kubernetes API service URL"
        local ctx=$(kubectl config current-context)
        local cluster=$(kubectl config view -o jsonpath="{.contexts[?(@.name == '$ctx')].context.cluster}")
        local server=$(kubectl config view -o jsonpath="{.clusters[?(@.name == '$cluster')].cluster.server}")
        verbose "URL: $server"

        #   determine a unique cluster id
        cluster=$(echo "$server" | sed -e 's;^https*://;;' -e 's;/.*$;;' -e 's;[^a-z0-9];-;g')
        verbose "Cluster-ID: $cluster"

        #   determine generated token of service account
        verbose "determine generated access token of service account \"$sa\""
        secret=$(kubectl -n "$ns" get sa "$sa" -o jsonpath="{.secrets[0].name}")
        token=$(kubectl -n "$ns" get secret "$secret" -o json | jq -r ".data.token | @base64d")

        #   generate K8S kubectl(1) configuration for service account
        verbose "generate kubectl(1) for service account \"$sa\" in namespace \"$ns\""
        cat <(conf kubeconfig \
            ns="$ns" sa="$sa" \
            server="$server" cluster="$cluster" \
            token="$token" context="$context")
    fi
}

#   dispatch according to command
if [[ $# -eq 0 ]]; then
    my_usage () {
        echo "k8s-util: USAGE: bash ${BASH_SOURCE} $*" 1>&2
    }
    my_usage "namespace <namespace> create|delete"
    my_usage "cluster-admin <namespace> <account> create|delete"
    my_usage "namespace-admin <namespace> <account> create|delete"
    my_usage "kubeconfig [<namespace> <account> <context>]"
    exit 1
fi
verbosity=false
if [[ $1 == "-v" ]]; then
    shift
    verbosity=true
fi
cmd="$1"; shift
eval "cmd_$(echo $cmd | sed -e 's;-;_;g')" "$@"
exit $?

