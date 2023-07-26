#!/bin/bash

function Runtime::waitFor() {
    local target=${1}
    local -i retriesFor=${2:-180} # seconds
    local -i interval=${3:-2}     # seconds

#    todo: check
    if ! Service::isServiceExist "${target}"; then
        return;
    fi

    local containers=$(docker ps --filter "name=${target}" --format "{{.Names}}")

    [ -z "${containers}" ] && Console::error "${WARN}Service ${INFO}\`${1}\`${WARN} is not running. Please check the name.${NC}" && exit 1

    for container in ${containers}; do
        local counter=1
        while :; do
            [ "${counter}" -gt 1 ] && echo -en "\rWaiting for ${container} [${counter}/${retriesFor}]..." || echo -en ""
            local status=$(docker inspect --format="{{json .State.Health.Status}}" "${container}")
            [ "${status}" = "\"healthy\"" ] && echo -en "${CLEAR}\r" && break
            [ "${counter}" -ge "${retriesFor}" ] && echo -e "\r${WARN}Could not wait for ${container} anymore.${NC} Container status: ${INFO}${status}${NC}" && exit 1
            counter=$((counter + interval))
            sleep "${interval}"
        done
    done
}
