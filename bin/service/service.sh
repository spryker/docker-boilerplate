#!/bin/bash

function Service::isServiceExist() {
    local serviceName="${1}"
    local isServiceShared="${FALSE}"
    local isServiceExist=''

    for sharedServiceName in ${SPRYKER_SHARED_SERVICES_LIST[@]}; do
        if [ "${serviceName}" == "${sharedServiceName}" ]; then
            isServiceShared="${TRUE}"

            break
        fi
    done

    if [ "${isServiceShared}" == "${TRUE}" ]; then
        serviceName="${SPRYKER_INTERNAL_PROJECT_NAME}_${serviceName}"
        isServiceExist=$(Compose::SharedServices::command config --services | grep "${serviceName}")
    else
        serviceName="${SPRYKER_PROJECT_NAME}_${serviceName}"
        isServiceExist=$(Compose::command config --services | grep "${serviceName}")
    fi

    if [ -z "${isServiceExist}" ]; then
        return ${FALSE};
    fi

    return ${TRUE}
}
