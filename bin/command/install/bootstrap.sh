#!/bin/bash

require docker

import environment/docker.sh
import environment/docker-compose.sh
import project/project.sh

Registry::addCommand "boot" "Command::bootstrap"
Registry::addCommand "bootstrap" "Command::bootstrap"

Registry::Help::section "Installation:"
Registry::Help::command -s -c "bootstrap | boot" -a "[-v] <project-yml-file>" "Prepares all the files to run the application based on ${HELP_HIGH}<project-yml-file>${HELP_DESC}."
Registry::Help::command -s -c "bootstrap | boot" -a "[-v]" "Prepares all the files to run the application based on ${HELP_HIGH}deploy.local.yml${HELP_DESC} or ${HELP_HIGH}deploy.yml${HELP_DESC}."

function Command::bootstrap() {

    while getopts ":vsx" opt; do
        case ${opt} in
            v)
                export VERBOSE=1
                ;;
            s)
                local SKIP_BOOTSTRAP_IF_DONE=1
                ;;
            x)
                export BOOT_IN_DEVELOPMENT=1
                ;;
            # Unknown option specified
            \?)
                Registry::printHelp
                Console::error "\nUnknown option ${INFO}-${OPTARG}${WARN} is acquired."
                exit 1
                ;;
            # Specified argument without required value
            :)
                Registry::printHelp
                Console::error "Option ${INFO}-${OPTARG}${WARN} requires an argument."
                exit 1
                ;;
        esac
    done
    shift $((OPTIND - 1))

    Project::validate

    local gitHash=$(git rev-parse --verify HEAD 2>/dev/null || true)
    local tmpDeploymentDir="${SOURCE_DIR}/deployment/_tmp"
    local defaultProjectYaml=$([ -f "./deploy.local.yml" ] && echo -n "./deploy.local.yml" || echo -n "./deploy.yml")
    local projectYaml=${1:-${defaultProjectYaml}}
    local projectDeployTemplatesDirectory="./config/deploy-templates/"

    if [ -n "${SKIP_BOOTSTRAP_IF_DONE}" ] && [ -f "${DESTINATION_DIR}/project.yml" ]; then
        if cmp -s "${DESTINATION_DIR}/project.yml" "${projectYaml}"; then
            if [ "$(cat "${DESTINATION_DIR}/_git" 2>/dev/null || true)" == "${gitHash}" ]; then
                Console::log "${CYAN}Bootstrap is skipped as the branch is still the same.${NC}" >&2
                Console::log "${DGRAY}Do not use ${LGRAY}-s${DGRAY} option to bootstrap anyway.${NC}" >&2
                exit 0
            fi
        fi
    fi

    if [ -f "${DEPLOY_SCRIPT}" ] && [ -z "${BOOT_IN_DEVELOPMENT}" ]; then
        Console::start "Stopping environment..."
        ${DEPLOY_SCRIPT} down >/dev/null 2>&1 && sleep 1 || true
        Console::end '[DONE]'
    fi

    if [ -d "${tmpDeploymentDir}" ]; then
        rm -rf "${tmpDeploymentDir}"
    fi
    mkdir "${tmpDeploymentDir}"

    Project::bootstrap "${tmpDeploymentDir}"

    tmpDeploymentDir="$(cd "${tmpDeploymentDir}" >/dev/null 2>&1 && pwd)"

    Command::bootstrap::_validateParameters

    Console::info "Using ${projectYaml}"

    local USER_FULL_ID=$(Environment::getFullUserId)

    Console::verbose::start "Building generator..."
    docker build -t spryker_docker_sdk \
        -f "${SOURCE_DIR}/generator/Dockerfile" \
        --build-arg="USER_UID=${USER_FULL_ID%%:*}" \
        -q \
        "${SOURCE_DIR}/generator" >/dev/null
    Console::end "[DONE]"

    Console::verbose::start "Copiyng assets..."
    cp -rf "${SOURCE_DIR}/bin" "${tmpDeploymentDir}/bin"
    cp -rf "${SOURCE_DIR}/context" "${tmpDeploymentDir}/context"
    cp -rf "${SOURCE_DIR}/bin/standalone" "${tmpDeploymentDir}/context/cli"
    cp -rf "${SOURCE_DIR}/images" "${tmpDeploymentDir}/images"
    cp "${projectYaml}" "${tmpDeploymentDir}/project.yml"
    cp "$([ -f "./.dockersyncignore" ] && echo './.dockersyncignore' || echo "${SOURCE_DIR}/.dockersyncignore.default")" "${tmpDeploymentDir}/.dockersyncignore"
    if [ -f ".known_hosts" ]; then
        cp ".known_hosts" "${tmpDeploymentDir}/"
    fi
    if [ -d "${projectDeployTemplatesDirectory}" ]; then
        cp -rf "${projectDeployTemplatesDirectory}" "${tmpDeploymentDir}/project-deploy-templates"
    fi
    Console::end "[DONE]"

    Console::info "${INFO}Running generator${NC}"

    # To support root user
    local userToRun=("-u" "${USER_FULL_ID}")
    if [ "${USER_FULL_ID%%:*}" != '0' ]; then
        userToRun=()
    fi

    docker run -i --rm "${userToRun[@]}" \
        -e SPRYKER_PLATFORM_IMAGE="${SPRYKER_PLATFORM_IMAGE:-""}" \
        -e SPRYKER_DOCKER_SDK_PLATFORM="${_PLATFORM}" \
        -e SPRYKER_DOCKER_SDK_DEPLOYMENT_DIR="${DESTINATION_DIR}" \
        -e SPRYKER_DOCKER_SDK_INTERNAL_DEPLOYMENT_DIR="${SPRYKER_DOCKER_SDK_INTERNAL_DEPLOYMENT_DIR}" \
        -e SPRYKER_PROJECT_NAME="${SPRYKER_PROJECT_NAME}" \
        -e SPRYKER_PROJECT_PATH="${SPRYKER_PROJECT_PATH}" \
        -e VERBOSE="${VERBOSE}" \
        -v "${SOURCE_DIR}/generator/src":/data/src:rw \
        -v "${tmpDeploymentDir}":/data/deployment:rw \
        spryker_docker_sdk

    chmod +x "${tmpDeploymentDir}/deploy"

    "${tmpDeploymentDir}/deploy" install

    Command::bootstrap::_deploy

    echo -n "${gitHash}" >"${DESTINATION_DIR}/_git"

    if [ ! -f ".dockerignore" ]; then
        cp "${SOURCE_DIR}/.dockerignore.default" .dockerignore
    fi

    Console::info "Deployment is generated into ${LGRAY}${DESTINATION_DIR}"

    Console::log "Use ${OK}docker/sdk$([ "${SPRYKER_PROJECT_NAME}" != $(basename $(pwd)) ] && echo -n " -p ${SPRYKER_PROJECT_NAME}") up${NC} to start the application."
    Console::log ''
}

function Command::bootstrap::_deploy() {

    if [ -n "${BOOT_IN_DEVELOPMENT}" ]; then
        Command::bootstrap::_injectDeployment
        return "${TRUE}"
    fi

    [ -d "${DESTINATION_DIR}" ] && rm -rf "${DESTINATION_DIR:?}/*"
    [ ! -d "${DESTINATION_DIR}" ] && mkdir "${DESTINATION_DIR}"
    cp -R "${tmpDeploymentDir}/." "${DESTINATION_DIR}"
    rm -rf "${tmpDeploymentDir}"
    Project::postBootstrap
}

function Command::bootstrap::_injectDeployment() {
    rm -rf "${DESTINATION_DIR:?}/bin"
    cp -R "${tmpDeploymentDir}/." "${DESTINATION_DIR}" || true
    rm -rf "${DESTINATION_DIR:?}/bin"
    ln -s "$(cd "${SOURCE_DIR}" && pwd)/bin" "${DESTINATION_DIR}/bin"
    rm -rf "${tmpDeploymentDir}"
}

function Command::bootstrap::_validateParameters() {
    [ -z "${SPRYKER_PROJECT_NAME}" ] && Console::error "SPRYKER_PROJECT_NAME is not set." && exit 1
    [ -z "${SOURCE_DIR}" ] && Console::error "SOURCE_DIR is not set." && exit 1

    [ ! -f "${projectYaml}" ] && Console::error "File \"${projectYaml}\" is not accessible." && exit 1
    [ ! -d "${tmpDeploymentDir}" ] && Console::error "Directory \"${tmpDeploymentDir}\" is not accessible." && exit 1
    [ ! -d "${SOURCE_DIR}" ] && Console::error "Directory \"${SOURCE_DIR}\" is not accessible." && exit 1

    Registry::checkRequirements

    return "${TRUE}"
}
