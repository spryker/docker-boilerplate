#!/usr/bin/env bash

Registry::addCommand "export" "Command::export"

Registry::Help::command -c "export images" -a "[-t <tag>]" "Builds prod-like images (Yves, Zed, Glue, Frontend)."
Registry::Help::command -c "export assets" -a "[-t <tag>] [-p <path>]" "[DEPRECATED] Builds assets and export as archives stored by given path."

function _assertDestinationDirectory() {
    if [ ! -d "${1}" ] || [ ! -w "${1}" ]; then
        Console::error "${WARN}Directory '${1}' is not accessible. Please, make sure it does exist and has appropriate permissions.${NC}"
        exit 1
    fi
}

function Command::export() {
    local subCommand=''
    local tag=${SPRYKER_DOCKER_TAG}
    local destinationPath='./'
    local pushDestination=''

    subCommand=${1}
    shift || true

    while getopts "t:p:d:" opt; do
        case "${opt}" in
            t)
                tag=${OPTARG}
                ;;
            p)
                # Deprecated
                destinationPath=${OPTARG}
                ;;
            d)
                pushDestination=${OPTARG}
                local pushDestinationPath="sdk/images/baked/${pushDestination}.sh"
                local pathToFile="${DEPLOYMENT_PATH}/bin/${pushDestinationPath}"
                if [ ! -f "${pathToFile}" ]; then
                    Console::error "\nUnknown export images destination - '${OPTARG}'."
                    exit 1
                fi

                import ${pushDestinationPath}
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
            *)
                echo ${opt}
                ;;
        esac
    done
    shift $((OPTIND - 1))

    case ${subCommand} in
        asset | assets)
            Console::warn 'This command is DEPRECATED. Please, use just "export".'
            _assertDestinationDirectory "${destinationPath}"
            Images::buildApplication --force
            Assets::build --force
            Images::buildFrontend --force
            Assets::export "${tag}" "${destinationPath}"
            ;;
        image | images)
            Console::verbose "${INFO}Build and export images${NC}"
            Images::buildApplication --force
            Assets::build --force
            Images::assetsCopy --force
            Images::buildFrontend --force
            Images::tagApplications "${tag}"
            Images::tagFrontend "${tag}"

            if [ -n "${pushDestination}" ]; then
                Images::push "${tag}"
            fi

            if [ -z "${pushDestination}" ]; then
                Images::printAll "${tag}"
            fi
            ;;
        *)
            Console::error "Unknown export '${subCommand}' is occurred. No action. Usage: ${HELP_SCR}${SELF_SCRIPT} export images [-t <tag>]" >&2
            exit 1
            ;;
    esac
}
