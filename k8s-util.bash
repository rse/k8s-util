#!/usr/bin/env bash
##
##  k8s-util -- Kubernetes (K8S) Utility
##  Copyright (c) 2019-2021 Dr. Ralf S. Engelschall <rse@engelschall.com>
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
    echo "k8s-util: USAGE: k8s-util $2" 1>&2
    exit 1
}

#   handle fatal error
fatal () {
    echo "k8s-util: ERROR: $*" 1>&2
    exit 1
}

#   path to configuration file
my_config=${K8S_UTIL_YAMLFILE-"$(dirname ${BASH_SOURCE})/k8s-util.yaml"}

#   path to run-command script
my_rcfile=${K8S_UTIL_RCFILE-"$(dirname ${BASH_SOURCE})/k8s-util.rc"}

#   path to run-time directory
my_basedir=${K8S_UTIL_BASEDIR-"$HOME/.k8s-util.d"}

#   fetch configuration
conf () {
    local id="$1"
    shift
    local cmd="sed -e \"1,/^%!${id}$/d\" -e \"/%!.*/,\\\$d\""
    for arg in "$@"; do
        local var=$(echo "$arg" | sed -e 's;=.*$;;')
        local val=$(echo "$arg" | sed -e 's;^[^=]*=;;')
        cmd="$cmd -e \"s;{{${var}}};${val};g\""
    done
    local tmpfile="${TMPDIR-/tmp}/k8s-util.$$.conf.tmp"
    eval "$cmd" <$my_config >$tmpfile
    if [[ $verbosity == true ]]; then
        sed -e "s;^;-- | ;" <$tmpfile 1>&2
    fi
    cat $tmpfile
    rm -f $tmpfile
}

#   copy content
copy () {
    local src="$1"
    local dst="$2"
    local mod="$3"
    if [[ $src == "-" ]]; then
        cat >"$dst"
    else
        cp "$src" "$dst"
    fi
    chmod $mod $dst
}

#   setup environment
cmd_setup () {
    #   allow downloading of programs to be enforced
    local force="no"
    if [[ $1 == "force" ]]; then
        force=yes
    fi

    #   create run-time directories
    if [[ ! -d "$my_basedir/bin" ]]; then
        ( umask 022 && mkdir -p "$my_basedir/bin" )
    fi
    if [[ ! -d "$my_basedir/etc/docker" ]]; then
        ( umask 022 && mkdir -p "$my_basedir/etc/docker" )
    fi
    if [[ ! -d "$my_basedir/etc/k8s" ]]; then
        ( umask 022 && mkdir -p "$my_basedir/etc/k8s" )
    fi

    #   check for existence of essential tools
    local which_docker=$(which docker)
    local which_compose=$(which docker-compose)
    local which_kubensx=$(which kubensx)
    local which_kubectl=$(which kubectl)
    local which_helm=$(which helm)
    local which_jq=$(which jq)

    #   ensure curl(1) exists if one of the tools have to downloaded
    if [[ $force == "yes" || \
          -z "$which_docker"   || \
          -z "$which_compose"  || \
          -z "$which_kubensx"  || \
          -z "$which_kubectl"  || \
          -z "$which_helm"     || \
          -z "$which_jq"            ]]; then
        #   ensure curl(1) is available
        if [[ -z "$(which curl)" ]]; then
            fatal "require curl(1) utility to download any tools"
        fi
    fi

    #   download docker(1)
    if [[ $force == "yes" || -z "$which_docker" ]]; then
        local docker_version=$(curl -sSkL https://github.com/docker/docker-ce/releases | \
            egrep 'releases/tag/v[0-9.]*"' | sed -e 's;^.*releases/tag/v;;' -e 's;".*$;;' | head -1)
        verbose "downloading docker(1) CLI (version $docker_version)"
        curl -sSkL $(printf "%s%s" \
            https://download.docker.com/linux/static/stable/x86_64/ \
            docker-${docker_version}.tgz) | \
            tar -z -x -f- --strip-components=1 -C $my_basedir/bin docker/docker
        chmod 755 $my_basedir/bin/docker
    fi

    #   download docker-compose(1)
    if [[ $force == "yes" || -z "$which_compose" ]]; then
        local compose_version=$(curl -sSkL https://github.com/docker/compose/releases | \
            egrep 'releases/tag/[0-9.]*"' | sed -e 's;^.*releases/tag/;;' -e 's;".*$;;' | head -1)
        verbose "downloading docker-compose(1) CLI (version $compose_version)"
        curl -sSkL $(printf "%s%s" \
            https://github.com/docker/compose/releases/download/${compose_version}/ \
            docker-compose-Linux-x86_64) -o $my_basedir/bin/docker-compose
        chmod 755 $my_basedir/bin/docker-compose
    fi

    #   download kubensx(1)
    if [[ $force == "yes" || -z "$which_kubensx" ]]; then
        local kubensx_version=$(curl -sSkL https://github.com/shyiko/kubensx/releases | \
            egrep 'releases/tag/[0-9.]*"' | sed -e 's;^.*releases/tag/;;' -e 's;".*$;;' | head -1)
        verbose "downloading kubensx(1) CLI (version $kubensx_version)"
        curl -sSkL -o $my_basedir/bin/kubensx $(printf "%s%s" \
            https://github.com/shyiko/kubensx/releases/download/ \
            ${kubensx_version}/kubensx-${kubensx_version}-linux-amd64)
        chmod 755 $my_basedir/bin/kubensx
    fi

    #   download kubectl(1)
    if [[ $force == "yes" || -z "$which_kubectl" ]]; then
        local kubernetes_version=$(curl -sSkL \
            https://storage.googleapis.com/kubernetes-release/release/stable.txt)
        verbose "downloading kubectl(1) CLI (version $kubernetes_version)"
        curl -sSkL -o $my_basedir/bin/kubectl $(printf "%s%s" \
            https://storage.googleapis.com/kubernetes-release/release/ \
            ${kubernetes_version}/bin/linux/amd64/kubectl)
        chmod 755 $my_basedir/bin/kubectl
    fi

    #   download helm(1)
    if [[ $force == "yes" || -z "$which_helm" ]]; then
        local helm_version=$(curl -sSkL https://github.com/kubernetes/helm/releases | \
            egrep 'releases/tag/v3\.[0-9.]*"' | sed -e 's;^.*releases/tag/v;;' -e 's;".*$;;' | head -1)
        verbose "downloading helm(1) CLI (version $helm_version)"
        curl -sSkL $(printf "%s%s" \
            https://get.helm.sh/ \
            helm-v${helm_version}-linux-amd64.tar.gz) | \
            tar -z -x -f - --strip-components=1 -C $my_basedir/bin linux-amd64/helm
        chmod 755 $my_basedir/bin/helm
    fi

    #   download jq(1)
    if [[ $force == "yes" || -z "$which_jq" ]]; then
        local jq_version=$(curl -sSkL https://github.com/stedolan/jq/releases | \
            egrep 'releases/tag/jq-[0-9.]*"' | sed -e 's;^.*releases/tag/jq-;;' -e 's;".*$;;' | head -1)
        verbose "downloading jq(1) CLI (version $jq_version)"
        curl -sSkL -o $my_basedir/bin/jq $(printf "%s%s" \
            https://github.com/stedolan/jq/releases/download/ \
            jq-${jq_version}/jq-linux64)
        chmod 755 $my_basedir/bin/jq
    fi
}

#   cleanup environment
cmd_cleanup () {
    rm -rf "$my_basedir"
}

#   configure Docker files
cmd_configure_docker () {
    local key="$1"
    local val="$2"
    case "$key" in
        url  ) echo "$val" >$my_basedir/etc/docker/url.txt ;;
        ca   ) copy "$val" $my_basedir/etc/docker/ca.pem   0600 ;;
        cert ) copy "$val" $my_basedir/etc/docker/cert.pem 0600 ;;
        key  ) copy "$val" $my_basedir/etc/docker/key.pem  0600 ;;
        *    ) fatal "unknown configuration part" ;;
    esac
}

#   configure Kubernetes files
cmd_configure_k8s () {
    local key="$1"
    local val="$2"
    copy "$val" "$my_basedir/etc/k8s/$key" 0600
}

#   provide environment
cmd_env () {
    sed -e "s;\$my_basedir;$my_basedir;g" <$my_rcfile
}

#   dump all K8S objects of a namespace
cmd_dump () {
    #   handle command-line arguments
    my_usage () {
        usage "$1" "dump <namespace> [<kubectl-get-options>]"
    }
    if [[ $# -lt 1 ]]; then
        my_usage "invalid number of arguments"
    fi
    ns="$1"; shift
    for name in $(kubectl -n "$ns" api-resources -o name --namespaced=true); do
        local out=$(kubectl -n "$ns" get "$name" --ignore-not-found "$@" 2>/dev/null)
        if [[ -n $out ]]; then
            echo "# ----( ${name} )----"
            echo "$out"
            echo ""
        fi
    done
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
        echo "k8s-util: USAGE: k8s-util $*" 1>&2
    }
    my_usage "setup [force]"
    my_usage "configure-docker url  <docker-host-url>"
    my_usage "configure-docker ca   <tls-client-ca-pem-file>"
    my_usage "configure-docker cert <tls-client-cert-pem-file>"
    my_usage "configure-docker key  <tls-client-key-pem-file>"
    my_usage "configure-k8s <kubeconfig-file>"
    my_usage "env"
    my_usage "dump <namespace> [<kubectl-get-options>]"
    my_usage "namespace <namespace> create|delete"
    my_usage "cluster-admin <namespace> <account> create|delete"
    my_usage "namespace-admin <namespace> <account> create|delete"
    my_usage "kubeconfig [<namespace> <account> <context>]"
    my_usage "cleanup"
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

