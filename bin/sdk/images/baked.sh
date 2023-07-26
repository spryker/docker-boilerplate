#!/bin/bash

import sdk/images/common.sh

function Images::buildApplication() {
    for arg in "${@}"; do
        case "${arg}" in
            '--force')
                # it is always it.
                ;;
            '--no-cache')
                # TODO implement --no-cache for build images
                ;;
            *)
                Console::verbose "\nUnknown option ${INFO}${arg}${WARN} is acquired for Images::buildApplication."
                ;;
        esac
    done

    Images::_buildApp baked
    Images::tagApplications "${SPRYKER_DOCKER_TAG}"
}

function Images::buildFrontend() {
    for arg in "${@}"; do
        case "${arg}" in
            '--force')
                # it is always it.
                ;;
            '--no-cache')
                # TODO implement --no-cache for build images
                ;;
            *)
                Console::verbose "\nUnknown option ${INFO}${arg}${WARN} is acquired for Images::buildFrontend."
                ;;
        esac
    done

    Images::_buildFrontend baked
#    todo:
    Images::_buildGateway
    Images::tagFrontend "${SPRYKER_DOCKER_TAG}"
}
