##
##  docker.bash -- Docker CLI provisioning (for standard contexts)
##  Copyright (c) 2019-2020 Dr. Ralf S. Engelschall <rse@engelschall.com>
##  Distributed under MIT license <https://spdx.org/licenses/MIT.html>
##
##  Usage:
##  | source k8s-util-env-docker.bash [<hostname> tcp|tls|ps]
##  | docker [...]
##  | docker-compose [...]
##

k8s_util_env_docker () {
    #   provisioning base directory
    local basedir="$(cd $(dirname ${BASH_SOURCE}) && pwd)/k8s-util-env-docker.d"
    if [[ ! -d "$basedir" ]]; then
        ( umask 022 && mkdir -p "$basedir/bin" "$basedir/etc" )
    fi

    #   provide path to etc directory
    local docker_bindir="$basedir/bin"
    local docker_etcdir="$basedir/etc"

    #   optionally extend the search path
    if [[ ! "$PATH" =~ (^|:)"$docker_bindir"(:|$) ]]; then
        PATH="$docker_bindir:$PATH"
    fi

    #   check for existence of docker(1) and docker-compose(1)
    local which_docker=$(which docker)
    local which_compose=$(which docker-compose)

    #   optionally download docker(1) and docker-compose(1)
    if [[ -z "$which_docker" || -z "$which_compose" ]]; then
        #   ensure curl(1) is available
        if [[ -z "$(which curl)" ]]; then
            echo "k8s-util: ERROR: require curl(1) utility to download files" 1>&2
            return 1
        fi

        #   download docker(1)
        if [[ -z "$which_docker" ]]; then
            local docker_version=$(curl -sSkL https://github.com/docker/docker-ce/releases | \
                egrep 'releases/tag/v[0-9.]*"' | sed -e 's;^.*releases/tag/v;;' -e 's;".*$;;' | head -1)
            echo "k8s-util: downloading docker(1) CLI (version $docker_version)"
            curl -sSkL $(printf "%s%s" \
                https://download.docker.com/linux/static/stable/x86_64/ \
                docker-${docker_version}.tgz) | \
                tar -z -x -f- --strip-components=1 -C $docker_bindir docker/docker
            chmod 755 $docker_bindir/docker
        fi

        #   download docker-compose(1)
        if [[ -z "$which_compose" ]]; then
            local compose_version=$(curl -sSkL https://github.com/docker/compose/releases | \
                egrep 'releases/tag/[0-9.]*"' | sed -e 's;^.*releases/tag/;;' -e 's;".*$;;' | head -1)
            echo "k8s-util: downloading docker-compose(1) CLI (version $compose_version)"
            curl -sSkL $(printf "%s%s" \
                https://github.com/docker/compose/releases/download/${compose_version}/ \
                docker-compose-Linux-x86_64) -o $docker_bindir/docker-compose
            chmod 755 $docker_bindir/docker-compose
        fi
    fi

    #   optionally provision for remote access
    if [[ $# -eq 2 ]]; then
        local server="$1"
        local kind="$2"
        echo "$server $kind"

        #   set docker(1) environment variables
        if [[ $kind == "tcp" ]]; then
            #   remote access via TCP
            export DOCKER_HOST="tcp://$server:2375"
        elif [[ $kind == "tls" || $kind == "ps" ]]; then
            #   remote access via TLS
            export DOCKER_HOST="tcp://$server:2376"
            export DOCKER_TLS=1
            if [[ -z "$DOCKER_TLS_VERIFY" ]]; then
                export DOCKER_TLS_VERIFY=1
            fi
            if [[ -z "$DOCKER_CERT_PATH" ]]; then
                export DOCKER_CERT_PATH="$docker_etcdir"
            fi
            if [[ $kind == "ps" ]]; then
                #   remote access via TLS in msg ProjectServer (PS) context
                if [[ ! -f "$DOCKER_CERT_PATH/ca.pem" ]]; then
                    echo "k8s-util: fetching CA certificate"
                    scp -q root@$server:/etc/docker/ca.crt $DOCKER_CERT_PATH/ca.pem
                    chmod 600 $DOCKER_CERT_PATH/ca.pem
                fi
                if [[ ! -f "$DOCKER_CERT_PATH/cert.pem" ]]; then
                    echo "k8s-util: fetching client certificate"
                    scp -q root@$server:/etc/docker/client.crt $DOCKER_CERT_PATH/cert.pem
                    chmod 600 $DOCKER_CERT_PATH/cert.pem
                fi
                if [[ ! -f "$DOCKER_CERT_PATH/key.pem" ]]; then
                    echo "k8s-util: fetching client private key"
                    scp -q root@$server:/etc/docker/client.key $DOCKER_CERT_PATH/key.pem
                    chmod 600 $DOCKER_CERT_PATH/key.pem
                fi
            fi
        fi
    fi
}

k8s_util_env_docker ${1+"$@"}
unset k8s_util_env_docker

