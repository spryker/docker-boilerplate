#!/bin/bash

function Service::Scheduler::isInstalled() {
    if ! Service::isServiceExist scheduler; then
        return;
    fi

    [ -n "${SPRYKER_TESTING_ENABLE}" ] && return "${TRUE}"

    Runtime::waitFor scheduler
    Console::start -n "Checking jobs are installed..."

    # shellcheck disable=SC2016
    # For avoid https://github.com/docker/compose/issues/9104
    local script="script=println Jenkins.instance.projects.findAll{ it.name.startsWith('${SPRYKER_PROJECT_NAME}') }.size"
    local jobsCount=$(Jenkins::callJenkins 'scriptText -d "'"${script}"'" | tail -n 1')

    [ "${jobsCount}" -gt 0 ] && Console::end "[INSTALLED]" && return "${TRUE}" || return "${FALSE}"
}

Service::Scheduler::pause() {
    if ! Service::isServiceExist scheduler; then
        return;
    fi

    [ -n "${SPRYKER_TESTING_ENABLE}" ] && return "${TRUE}"

    Runtime::waitFor scheduler
    Console::start -n "Suspending scheduler..."

    # shellcheck disable=SC2016
    Compose::exec 'curl -sLI -X POST ${SPRYKER_SCHEDULER_HOST}:${SPRYKER_SCHEDULER_PORT}/quietDown' "${DOCKER_COMPOSE_TTY_DISABLED}" >/dev/null || true

    # TODO Send SIGTERM in cli-rpc.js
    local counter=1
    local interval=2
    local waitFor=60
    while :; do
        # shellcheck disable=SC2016
        # For avoid https://github.com/docker/compose/issues/9104
        local runningJobsCount=$(Jenkins::callJenkins 'computer/api/xml?xpath=*/busyExecutors/text\(\) | tail -n 1')
        [ "${runningJobsCount}" -eq 0 ] && break
        [ "${counter}" -ge "${waitFor}" ] && break
        counter=$((counter + interval))
        sleep "${interval}"
    done

    Console::end "[DONE]"
}

Service::Scheduler::unpause() {
    if ! Service::isServiceExist scheduler; then
        return;
    fi

    [ -n "${SPRYKER_TESTING_ENABLE}" ] && return "${TRUE}"

    Runtime::waitFor scheduler
    Console::start -n "Resuming scheduler..."

    # shellcheck disable=SC2016
    # For avoid https://github.com/docker/compose/issues/9104
    Compose::exec 'curl -sLI -X POST ${SPRYKER_SCHEDULER_HOST}:${SPRYKER_SCHEDULER_PORT}/cancelQuietDown' "${DOCKER_COMPOSE_TTY_DISABLED}" >/dev/null || true
    Console::end "[DONE]"
}

function Service::Scheduler::start() {
    if ! Service::isServiceExist scheduler; then
        return;
    fi

    local force=''
    if [ "$1" == '--force' ]; then
        force=1
        shift || true
    fi

    if [ -z "${force}" ] && Service::Scheduler::isInstalled; then
        return "${TRUE}"
    fi

    Service::Scheduler::_run setup "Creating"
}

function Service::Scheduler::stop() {
    if ! Service::isServiceExist scheduler; then
        return;
    fi

    Service::Scheduler::_run suspend "Suspending"
}

function Service::Scheduler::clean() {
    if ! Service::isServiceExist scheduler; then
        return;
    fi

    Service::Scheduler::_run clean "Cleaning"
}

function Service::Scheduler::_run() {
    if ! Service::isServiceExist scheduler; then
        return;
    fi

    [ -n "${SPRYKER_TESTING_ENABLE}" ] && return "${TRUE}"

    Runtime::waitFor scheduler

    for region in "${SPRYKER_STORES[@]}"; do
        eval "${region}"
        if [ ${#STORES[@]} -eq 0 ]; then
            SPRYKER_CURRENT_REGION="${REGION}"
            Console::info "${2} scheduler jobs for ${SPRYKER_CURRENT_REGION} region."
            Compose::exec "vendor/bin/install -r ${SPRYKER_PIPELINE} -s scheduler-${1}"
        else
            for store in "${STORES[@]}"; do
                SPRYKER_CURRENT_REGION=""
                SPRYKER_CURRENT_STORE="${store}"
                Console::info "${2} scheduler jobs for ${SPRYKER_CURRENT_STORE} store."
                Compose::exec "vendor/bin/install -r ${SPRYKER_PIPELINE} -s scheduler-${1}"
            done
        fi
    done
}

function Jenkins::callJenkins() {
    local uri=${1}

    local cookieJar="/data/jenkins_cookie_jar"
    local statusCode=$(Compose::exec 'curl -o /dev/null -s -w "%{http_code}\n" ${SPRYKER_SCHEDULER_HOST}:${SPRYKER_SCHEDULER_PORT}/crumbIssuer/api/json | tail -n 1' "${DOCKER_COMPOSE_TTY_DISABLED}"| tr -d " \n\r")
    local curlOptions='-sL'

    local crumbToken=''
    local crumbHeader=''
    local composeCommand=''

    if [ "${statusCode}" -ne '200' ]; then
        composeCommand=$(printf 'curl %s ${SPRYKER_SCHEDULER_HOST}:${SPRYKER_SCHEDULER_PORT}/%s' "${curlOptions}" "${uri}")
    else
        Compose::exec 'rm -f '${cookieJar}' && touch '${cookieJar}
        crumbToken=$(Compose::exec 'curl -sL --cookie-jar '"${cookieJar}"' ${SPRYKER_SCHEDULER_HOST}:${SPRYKER_SCHEDULER_PORT}/crumbIssuer/api/json | jq -r ".crumbRequestField + \":\" + .crumb"' "${DOCKER_COMPOSE_TTY_DISABLED}"| tr -d " \n\r")
        crumbHeader="-H \"${crumbToken}\" --cookie \"${cookieJar}\""
        curlOptions+=' '${crumbHeader}
        composeCommand=$(printf 'curl %s ${SPRYKER_SCHEDULER_HOST}:${SPRYKER_SCHEDULER_PORT}/%s' "${curlOptions}" "${uri}")
    fi

    local result=$(Compose::exec ${composeCommand} "${DOCKER_COMPOSE_TTY_DISABLED}"| tr -d " \n\r")
    Compose::exec 'rm -f '${cookieJar}

    echo ${result}
}
