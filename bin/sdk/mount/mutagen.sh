#!/bin/bash

require docker grep awk

import lib/version.sh
import lib/string.sh

import environment/docker-compose.sh

# shellcheck disable=SC2034

function Mount::logs() {
    mutagen sync monitor "${SPRYKER_SYNC_SESSION_NAME}"
}

function sync() {
    # @deprecated

    return "${TRUE}"
}

function Mount::Mutagen::beforeUp() {
    local sessionStatus

    # Let's clean volume on cold start when containers are not running to avoid offline conflicts
    # The volume will not be deleted if any app container is running.
    docker volume rm "${SPRYKER_SYNC_VOLUME}" >/dev/null 2>&1 || true

    updateComposeCovertWindowsPaths
    terminateMutagenSessionsWithObsoleteDockerId

    # Clean content of the sync volume if the sync session is terminated or halted.
    sessionStatus=$(mutagen sync list "${SPRYKER_SYNC_SESSION_NAME}" 2>/dev/null | grep 'Status:' | awk '{print $2}' || echo '')
    if [ -z "${sessionStatus}" ] || [ "${sessionStatus}" == 'Halted' ]; then
        Console::verbose::start "${INFO}Cleaning previous synced files${NC}"
        mutagen sync terminate "${SPRYKER_SYNC_SESSION_NAME}" >/dev/null 2>&1 || true
        docker run -i --rm -v "${SPRYKER_SYNC_VOLUME}:/data" busybox find /data/ ! -path /data/ -delete >/dev/null 2>&1 || true
        Console::end "[OK]"
    fi
}

# https://github.com/docker/compose/issues/9428
function updateComposeCovertWindowsPaths() {
    local mutagenInstalledVersion="$(Mount::Mutagen::getInstalledVersion)"
	local installedVersion=$(Version::parse ${mutagenInstalledVersion})

    if [ "${installedVersion:0:2}" -ge 14 ]; then
        export COMPOSE_CONVERT_WINDOWS_PATHS=0
    fi
}

function terminateMutagenSessionsWithObsoleteDockerId() {
    dockerId=$(docker info --format '{{.ID}}' 2>/dev/null | awk '{ gsub(":","_",$1); print $1 }' || echo '')

    if [ -z "$dockerId" ]; then
        Console::error "${WARN}Docker ID is empty, please check the script and try again."
        return
    fi

    Console::log "Checking mutagen sessions for docker ID: ${dockerId}"

    sessionIds=$(mutagen sync list "${SPRYKER_SYNC_SESSION_NAME}" 2>/dev/null | grep 'Identifier:' | awk '{print $2}' || echo '')

    for sessionId in ${sessionIds}; do
        if [ -z "$sessionId" ]; then
            Console::warn "Session ID is empty, please check the script and try again."
            continue
        fi

        sessionDockerId=$(mutagen sync list "${sessionId}" 2>/dev/null | grep 'io.mutagen.compose.daemon.identifier:' | awk '{print $2}' || echo '')

        if [ -z "$sessionDockerId" ]; then
           Console::warn "Docker ID for session ${sessionId} is empty, please check the script and try again."
            continue
        fi

        if [ "$sessionDockerId" != "$dockerId" ]; then
            mutagen sync terminate "${sessionId}"
            Console::log "Mutagen session ${sessionId} has been terminated."
        fi
    done
}

# This is necessary due to https://github.com/mutagen-io/mutagen/issues/224
function Mount::Mutagen::beforeRun() {
    Console::verbose::start "${INFO}Creating file syncronization volume${NC}"
    docker volume create --name="${SPRYKER_SYNC_VOLUME}" >/dev/null
    docker run -it --rm -v "${SPRYKER_SYNC_VOLUME}:/data" busybox chmod 777 /data >/dev/null 2>&1
    Console::end "[OK]"
}

# This is necessary due to https://github.com/mutagen-io/mutagen/issues/225
# Issue was fixed. Function is Deprecated
function Mount::Mutagen::afterCliReady() {
    return ${TRUE}
}

# should be removed. We are using mutagen compose
function Mount::Mutagen::afterDown() {
    return ${TRUE}
}

function Mount::Mutagen::install() {
	local isMutagenInstalled=$(Mount::Mutagen::isMutagenInstalled)

	if [ -n "${isMutagenInstalled}" ]; then
		Console::error "${isMutagenInstalled}"

		return "${FALSE}"
	fi

	local validateMutagenVersion=$(Mount::Mutagen::validateMutagenVersion)
	if [ -n "${validateMutagenVersion}" ]; then
        Console::error "${validateMutagenVersion}"

        return "${FALSE}"
    fi

    return "${TRUE}"
}

function Mount::Mutagen::getInstalledVersion() {
	echo $(String::trimWhitespaces "$(
         command -v mutagen >/dev/null 2>&1
         # shellcheck disable=SC2015
         test $? -eq 0 && mutagen version
     )")
}

function Mount::Mutagen::getDockerComposeSubstitute() {
	local mutagenInstalledVersion="$(Mount::Mutagen::getInstalledVersion)"
	local installedVersion=$(Version::parse ${mutagenInstalledVersion})

    if [ "${installedVersion:0:2}" -ge 13 ]; then
        if [ -z "${mutagenInstalledVersion##*'-beta'*}" ] ;then
            echo 'mutagen compose'
        else
            echo 'mutagen-compose'
        fi
    else
		echo 'mutagen compose'
    fi
}

function Mount::Mutagen::getInstallLink() {
	local dockerComposeInstalledVersion=${1}
	local installLink

    if [ "${dockerComposeInstalledVersion:0:1}" -lt 2 ]; then
        requiredMinimalVersion=${requiredMinimalVersionForDockerComposeV1}
        installLink='mutagen-io/mutagen/mutagen-beta'
    else
        requiredMinimalVersion=${requiredMinimalVersionForDockerComposeV2}
        installLink='mutagen-io/mutagen/mutagen'
    fi

    echo ${installLink}
}

function Mount::Mutagen::getMutagenMinimalVersion() {
	local dockerComposeInstalledVersion=${1}
    local requiredMinimalVersionForDockerComposeV1='0.12.0'
    local requiredMinimalVersionForDockerComposeV2='0.13.0'

	local requiredMinimalVersion

    if [ "${dockerComposeInstalledVersion:0:1}" -lt 2 ]; then
        requiredMinimalVersion=${requiredMinimalVersionForDockerComposeV1}
    else
        requiredMinimalVersion=${requiredMinimalVersionForDockerComposeV2}
    fi

    echo ${requiredMinimalVersion}
}

function Mount::Mutagen::getInstallMessage() {
	local dockerComposeInstalledVersion=${1}
	local installLink=${2}

	local message="brew install ${installLink}"
    local composeInstallLink='mutagen-io/mutagen/mutagen-compose'

    if [ "${dockerComposeInstalledVersion:0:1}" == 2 ]; then
        message+=" ${composeInstallLink}"
    fi

    echo ${message}
}

function Mount::Mutagen::isMutagenInstalled() {
	local dockerComposeInstalledVersion=$(Environment::getDockerComposeVersion)

	local installLink=$(Mount::Mutagen::getInstallLink "${dockerComposeInstalledVersion}")
    local installedVersion=$(Mount::Mutagen::getInstalledVersion)
    local requiredMinimalVersion=$(Mount::Mutagen::getMutagenMinimalVersion "${dockerComposeInstalledVersion}")

    if [ -z "${installedVersion}" ]; then
        errorMessage+="\nMutagen.io binary is not available. Please, install Mutagen.io. Minimum required version is: ${requiredMinimalVersion}.\n"

        if [ "${_PLATFORM}" == 'macos' ]; then
            errorMessage+="$(Mount::Mutagen::getInstallMessage "${dockerComposeInstalledVersion}" "${installLink}")"
        fi

        echo "${errorMessage}"
    fi
}

function Mount::Mutagen::validateMutagenVersion() {
	local dockerComposeInstalledVersion=$(Environment::getDockerComposeVersion)

	local installLink=$(Mount::Mutagen::getInstallLink "${dockerComposeInstalledVersion}")
    local installedVersion=$(Mount::Mutagen::getInstalledVersion)
    local requiredMinimalVersion=$(Mount::Mutagen::getMutagenMinimalVersion "${dockerComposeInstalledVersion}")

    local errorMessage="\n"

    if [ "$(Version::parse "${installedVersion}")" -lt "$(Version::parse "${requiredMinimalVersion}")" ]; then
        errorMessage+="Mutagen.io version ${installedVersion} is not supported. Please, update Mutagen.io to at least ${requiredMinimalVersion}."

        if [ "${_PLATFORM}" == 'macos' ]; then
            errorMessage+="\nbrew list | grep mutagen | xargs ${XARGS_NO_RUN_IF_EMPTY} brew remove && $(Mount::Mutagen::getInstallMessage ${dockerComposeInstalledVersion} ${installLink}) && mutagen daemon stop && mutagen daemon start"
        fi

        echo ${errorMessage}

		Console::error "${errorMessage}"

        return "${FALSE}"
    else
        local parsedInstallVersion=$(Version::parse "${installedVersion}")
        if [ -n "$( echo ${installedVersion} | sed -n '/beta/p')" ] && [ "${parsedInstallVersion:0:2}" -eq 13 ] && [ "$(Environment::IsDockerComposeV2Enabled)" == "${TRUE}" ]; then
			errorMessage+="Mutagen.io version ${installedVersion} is not supported. Please, update Mutagen.io to at least ${requiredMinimalVersion}."

            if [ "${_PLATFORM}" == 'macos' ]; then
                errorMessage+="\nbrew list | grep mutagen | xargs ${XARGS_NO_RUN_IF_EMPTY} brew remove && $(Mount::Mutagen::getInstallMessage ${dockerComposeInstalledVersion} ${installLink}) && mutagen daemon stop && mutagen daemon start"
            fi

            echo "${errorMessage}"
        fi
    fi
}

function Mount::Mutagen::checkMutagenVersion() {
	local isMutagenInstalled=$(Mount::Mutagen::isMutagenInstalled)

	if [ -n "${isMutagenInstalled}" ]; then
		Console::error "${isMutagenInstalled}"

		exit 1
	fi

	local validateMutagenVersion=$(Mount::Mutagen::validateMutagenVersion)
	if [ -n "${validateMutagenVersion}" ]; then
        Console::error "${validateMutagenVersion}"

        exit 1
    fi
}
DOCKER_COMPOSE_SUBSTITUTE="$(Mount::Mutagen::getDockerComposeSubstitute)"

Registry::Flow::addBeforeUp 'Mount::Mutagen::beforeUp'
Registry::Flow::addBeforeRun 'Mount::Mutagen::beforeRun'
Registry::Flow::addAfterCliReady 'Mount::Mutagen::afterCliReady'
Registry::Flow::addAfterDown 'Mount::Mutagen::afterDown'
Registry::addInstaller 'Mount::Mutagen::install'
Registry::addChecker 'Mount::Mutagen::checkMutagenVersion'
