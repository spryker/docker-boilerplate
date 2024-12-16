#!/usr/bin/env bash

export DOCKER_BUILDKIT=1

require docker tr
require:linux ip grep awk
require:macos ipconfig
require:windows tail cut

import lib/version.sh
import lib/string.sh

# ------------------
function Environment::checkDockerVersion() {
    Console::verbose::start "Checking docker version..."

    local requiredMinimalVersion=${1:-'18.09.1'}
    local installedVersion=$(String::trimWhitespaces "$(
        command -v docker >/dev/null
        # shellcheck disable=SC2015
        test $? -eq 0 && docker version --format '{{.Server.Version}}'
    )")

    if [ -z "${installedVersion}" ]; then
        Console::error "Docker is not running. Please, make sure Docker is installed and running."
        exit 1
    fi

    if [ "$(Version::parse "${installedVersion}")" -lt "$(Version::parse "${requiredMinimalVersion}")" ]; then
        Console::error "Docker version ${installedVersion} is not supported. Please, update docker to at least ${requiredMinimalVersion}."
        exit 1
    fi

    Environment::checkDependenciesByVersion "${installedVersion}"
    Console::end "[OK]"
}

function Environment::checkDependenciesByVersion() {
    local installedVersion=${1}
    local requiredMinimalVersionWithBuildx='23.0.0'

    if [ "$(Version::parse "${installedVersion}")" -ge "$(Version::parse "${requiredMinimalVersionWithBuildx}")" ]; then
        local isBuildxExist=$(docker --help | grep buildx)

        if [ -z "${isBuildxExist}" ]; then
            Console::error "Docker Buildx plugin is not installed. Please, make sure Docker Buildx plugin is installed. How to install Docker Buildx(https://docs.docker.com/build/install-buildx/)"
            exit 1
        fi
    fi
}

# ------------------
function Environment::isDockerMachineActive() {
    if [ -n "${DOCKER_MACHINE_NAME}" ]; then
        return "${TRUE}"
    fi

    return "${FALSE}"
}

# ------------------
function Environment::getDockerIp() {
    if [ -n "${DOCKER_MACHINE_NAME}" ]; then
        echo -n "$(docker-machine ip "${DOCKER_MACHINE_NAME}" | tr -d " \n")"
        return "${TRUE}"
    fi

    echo -n '127.0.0.1'
    return "${TRUE}"
}

# ------------------
function Environment::isWSL() {
    # See https://github.com/microsoft/WSL/issues/423#issuecomment-221627364
    if grep -sqi microsoft /proc/sys/kernel/osrelease; then
        return "${TRUE}"
    fi

    return "${FALSE}"
}

# ------------------
function Environment::getHostIp() {

    local myIp='host.docker.internal'

    case ${_PLATFORM} in
        linux)
            if ! Environment::isWSL; then
                myIp=$(ip route get 1 | sed 's/^.*src \([^ ]*\).*$/\1/;q')
            fi
            ;;
        macos)
            if Environment::isDockerMachineActive; then
                myIp=$(ipconfig getifaddr en0)
            fi
            ;;
        windows)
            if Environment::isDockerMachineActive; then
                # TODO check windows host IP in WSL and WSL2
                myIp=$(tail -1 /etc/resolv.conf | cut -d' ' -f2)
            fi
            ;;
    esac

    echo "${myIp}"
    return "${TRUE}"
}

# ------------------
function Environment::getFullUserId() {
    local USER_UID=1000
    local USER_GID=1000
    [ "${_PLATFORM}" == "linux" ] && ! Environment::isDockerMachineActive && USER_UID=$(id -u) && USER_GID=$(id -g)

    echo -n "${USER_UID}:${USER_GID}"
    return "${TRUE}"
}

#Registry::addChecker 'Environment::checkDockerVersion'
