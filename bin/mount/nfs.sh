#!/bin/bash

set -e

pushd "${BASH_SOURCE%/*}" > /dev/null
. ../constants.sh
. ../console.sh

../require.sh docker docker-sync
popd > /dev/null

function sync()
{
    local volumeName="${SPRYKER_DOCKER_PREFIX}_${SPRYKER_DOCKER_TAG}_data_sync"

    case $1 in
        create)
            verbose "${INFO}Creating 'data-sync' volume${NC}"
            docker volume create --driver local --opt type=nfs \
                --opt o=addr=host.docker.internal,rw,nolock,fsc,ac,noatime,async,nointr,nfsvers=3 \
                --opt device=":${PROJECT_DIR}" \
                --name="${volumeName}" \
                > /dev/null
            ;;

        clean)
            docker volume rm "${volumeName}" > /dev/null 2>&1 || true
            ;;

        stop)
            ;;

        start)
            sync clean
            sync create
            ;;
    esac
}

export -f sync
