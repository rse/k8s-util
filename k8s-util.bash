#!/usr/bin/env bash
##
##  k8s-util -- Kubernetes (K8S) Utility
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
    echo "k8s-util: USAGE: k8s-util $2" 1>&2
    exit 1
}

#   handle fatal error
fatal () {
    echo "k8s-util: ERROR: $*" 1>&2
    exit 1
}

#   path to configuration file
my_config="$(dirname ${BASH_SOURCE})/k8s-util.yaml"

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

#   establish Docker environment
cmd_env_docker () {
    #   a temporary storage area
    local output="${TMPDIR-/tmp}/k8s-util.$$.tmp"
    cp /dev/null $output

    #   provisioning base directory
    local my_basedir="$HOME/.k8s-util.d"
    if [[ ! -d "$my_basedir/bin" ]]; then
        ( umask 022 && mkdir -p "$my_basedir/bin" )
    fi
    if [[ ! -d "$my_basedir/etc/docker" ]]; then
        ( umask 022 && mkdir -p "$my_basedir/etc/docker" )
    fi

    #   optionally extend the search path
    if [[ ! "$PATH" =~ (^|:)"$my_basedir/bin"(:|$) ]]; then
        echo "PATH=\"$my_basedir/bin:\$PATH\"" >>$output
    fi

    #   check for existence of docker(1) and docker-compose(1)
    local which_docker=$(which docker)
    local which_compose=$(which docker-compose)

    #   optionally download docker(1) and docker-compose(1)
    if [[ -z "$which_docker" || -z "$which_compose" ]]; then
        #   ensure curl(1) is available
        if [[ -z "$(which curl)" ]]; then
            fatal "require curl(1) utility to download files"
        fi

        #   download docker(1)
        if [[ -z "$which_docker" ]]; then
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
        if [[ -z "$which_compose" ]]; then
            local compose_version=$(curl -sSkL https://github.com/docker/compose/releases | \
                egrep 'releases/tag/[0-9.]*"' | sed -e 's;^.*releases/tag/;;' -e 's;".*$;;' | head -1)
            verbose "downloading docker-compose(1) CLI (version $compose_version)"
            curl -sSkL $(printf "%s%s" \
                https://github.com/docker/compose/releases/download/${compose_version}/ \
                docker-compose-Linux-x86_64) -o $my_basedir/bin/docker-compose
            chmod 755 $my_basedir/bin/docker-compose
        fi
    fi

    #   optionally provision for remote access
    if [[ $# -eq 2 ]]; then
        local server="$1"
        local kind="$2"

        #   set docker(1) environment variables
        if [[ $kind == "tcp" ]]; then
            #   remote access via TCP
            echo "export DOCKER_HOST=\"tcp://$server:2375\"" >>$output
        elif [[ $kind == "tls" || $kind == "ps" ]]; then
            #   remote access via TLS
            echo "export DOCKER_HOST=\"tcp://$server:2376\"" >>$output
            echo "export DOCKER_TLS=1" >>$output
            if [[ -z "$DOCKER_TLS_VERIFY" ]]; then
                echo "export DOCKER_TLS_VERIFY=1" >>$output
            fi
            if [[ -z "$DOCKER_CERT_PATH" ]]; then
                echo "export DOCKER_CERT_PATH=\"$my_basedir/etc/docker\"" >>$output
                DOCKER_CERT_PATH="$my_basedir/etc/docker"
            fi
            if [[ $kind == "ps" ]]; then
                #   remote access via TLS in msg ProjectServer (PS) context
                if [[ ! -f "$DOCKER_CERT_PATH/ca.pem" ]]; then
                    verbose "fetching CA certificate"
                    scp -q root@$server:/etc/docker/ca.crt $DOCKER_CERT_PATH/ca.pem
                    chmod 600 $DOCKER_CERT_PATH/ca.pem
                fi
                if [[ ! -f "$DOCKER_CERT_PATH/cert.pem" ]]; then
                    verbose "fetching client certificate"
                    scp -q root@$server:/etc/docker/client.crt $DOCKER_CERT_PATH/cert.pem
                    chmod 600 $DOCKER_CERT_PATH/cert.pem
                fi
                if [[ ! -f "$DOCKER_CERT_PATH/key.pem" ]]; then
                    verbose "fetching client private key"
                    scp -q root@$server:/etc/docker/client.key $DOCKER_CERT_PATH/key.pem
                    chmod 600 $DOCKER_CERT_PATH/key.pem
                fi
            fi
        fi
    fi

    #   provide output
    cat $output
    rm -f $output
}

#   establish Kubernetes environment
cmd_env_k8s () {
    #   a temporary storage area
    local output="${TMPDIR-/tmp}/k8s-util.$$.tmp"
    cp /dev/null $output

    #   provisioning base directory
    local my_basedir="$HOME/.k8s-util.d"
    if [[ ! -d "$my_basedir/bin" ]]; then
        ( umask 022 && mkdir -p "$my_basedir/bin" )
    fi
    if [[ ! -d "$my_basedir/etc/k8s" ]]; then
        ( umask 022 && mkdir -p "$my_basedir/etc/k8s" )
    fi

    #   optionally extend the search path
    if [[ ! "$PATH" =~ (^|:)"$my_basedir/bin"(:|$) ]]; then
        echo "PATH=\"$my_basedir/bin:\$PATH\"" >>$output
    fi

    #   check for existence of kubectl(1) and helm(1)
    local which_kubectl=$(which kubectl)
    local which_helm=$(which helm)

    #   optionally download kubectl(1) and helm(1)
    if [[ -z "$which_kubectl" || -z "$which_helm" ]]; then
        #   ensure curl(1) is available
        if [[ -z "$(which curl)" ]]; then
            fatal "require curl(1) utility to download files"
        fi

        #   download kubectl(1)
        if [[ -z "$which_kubectl" ]]; then
            local kubernetes_version=$(curl -sSkL \
                https://storage.googleapis.com/kubernetes-release/release/stable.txt)
            echo "k8s-util: downloading kubectl(1) CLI (version $kubernetes_version)" 1>&2
            curl -sSkL -o $my_basedir/bin/kubectl $(printf "%s%s" \
                https://storage.googleapis.com/kubernetes-release/release/ \
                ${kubernetes_version}/bin/linux/amd64/kubectl)
            chmod 755 $my_basedir/bin/kubectl
        fi

        #   download helm(1)
        if [[ -z "$which_helm" ]]; then
            local helm_version=$(curl -sSkL https://github.com/kubernetes/helm/releases | \
                egrep 'releases/tag/v[0-9.]*"' | sed -e 's;^.*releases/tag/v;;' -e 's;".*$;;' | head -1)
            echo "k8s-util: downloading helm(1) CLI (version $helm_version)" 1>&2
            curl -sSkL $(printf "%s%s" \
                https://get.helm.sh/ \
                helm-v${helm_version}-linux-amd64.tar.gz) | \
                tar -z -x -f - --strip-components=1 -C $my_basedir/bin linux-amd64/helm
            chmod 755 $my_basedir/bin/helm
        fi
    fi

    #   install Bash tab completions
    echo "source <(KUBECONFIG=/dev/null kubectl completion bash)" >>$output
    echo "source <(KUBECONFIG=/dev/null helm completion bash)" >>$output

    #   optionally provision for remote access
    if [[ $# -ge 1 ]]; then
        if [[ $# -eq 1 && -f "$1" ]]; then
            echo "export KUBECONFIG=\"$1\"" >>$output
        else
            #   provision for remote access in msg Project Server (PS) context
            local server=$1
            local username=${2-"admin"}
            local contextname=${3-""}

            #   expose Kubernetes access configuration
            echo "export KUBECONFIG=\"$my_basedir/etc/k8s/kubeconfig.yaml\"" >>$output

            #   optionally fetch Kubernetes access configuration
            if [[ ! -f "$KUBECONFIG" ]]; then
                echo "k8s-util: fetching kubectl(1) access configuration" 1>&2
                ssh -q -t root@$server docker-stack exec ase-k3s \
                    kubeconfig "${username}" "${contextname}" >"$my_basedir/etc/k8s/kubeconfig.yaml"
            fi
        fi
    fi

    #   provide output
    cat $output
    rm -f $output
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
        #   ensure the required tool is available
        if [[ -z "$(which jq)" ]]; then
            fatal "require jq(1) in \$PATH"
        fi

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

#   ensure the required tool is available
if [[ -z "$(which kubectl)" ]]; then
    fatal "require kubectl(1) in \$PATH"
fi

#   dispatch according to command
if [[ $# -eq 0 ]]; then
    my_usage () {
        echo "k8s-util: USAGE: k8s-util $*" 1>&2
    }
    my_usage "env-docker [<hostname> tcp|tls|ps]"
    my_usage "env-k8s [<kubeconfig-file> | <hostname> [<username> [<context>]]]"
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

