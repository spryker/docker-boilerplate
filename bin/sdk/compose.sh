#!/bin/bash

# shellcheck disable=SC2155

require docker tr awk wc sed grep

Registry::Flow::addBoot "Compose::verboseMode"

function Compose::getComposeFiles() {
    local composeFiles="-f ${DEPLOYMENT_PATH}/../${SPRYKER_INTERNAL_PROJECT_NAME}/${SPRYKER_PROJECT_NAME}.docker-compose.yml"

    for composeFile in ${DOCKER_COMPOSE_FILES_EXTRA}; do
        composeFiles+=" -f ${composeFile}"
    done

    echo "${composeFiles}"
}

function Compose::ensureTestingMode() {
    SPRYKER_TESTING_ENABLE=1
#    todo: chould be project namespace
    local isTestMode=$(docker ps --filter 'status=running' --filter "name=${SPRYKER_PROJECT_NAME}_webdriver_*" --format "{{.Names}}")
    if [ -z "${isTestMode}" ]; then
        Compose::run
    fi
}

function Compose::ensureRunning() {
    local service=${1:-${SPRYKER_PROJECT_NAME}_'cli'}
    local isCliRunning=$(docker ps --filter 'status=running' --filter "name=${service}" --format "{{.Names}}")
    if [ -z "${isCliRunning}" ]; then
        Compose::run
    fi
}

function Compose::ensureCliRunning() {
    local isCliRunning=$(docker ps --filter 'status=running' --filter "ancestor=${SPRYKER_DOCKER_PREFIX}_run_cli:${SPRYKER_DOCKER_TAG}" --filter "name=${SPRYKER_DOCKER_PREFIX}_cli_*" --format "{{.Names}}")
    if [ -z "${isCliRunning}" ]; then
#        todo: check
        Compose::runCliDependencyServices
        Compose::run --no-deps ${SPRYKER_PROJECT_NAME}_cli ${SPRYKER_PROJECT_NAME}_cli_ssh_relay
        Registry::Flow::runAfterCliReady
    fi
}

# ---------------
function Compose::exec() {
    local tty
    [ -t -0 ] && tty='' || tty='-T'

	# For avoid https://github.com/docker/compose/issues/9104
	local ttyDisabledKey='docker_compose_tty_disabled'
	local lastArg="${@: -1}"
	if [ "${DOCKER_COMPOSE_TTY_DISABLED}" = "${lastArg}" ]; then
		if  [ "${DOCKER_COMPOSE_TTY_DISABLED}" = "${ttyDisabledKey}" ]; then
			tty='-T'
		fi

		set -- "${@:1:$(($#-1))}"
	fi

    Compose::command exec ${tty} \
        -e COMMAND="${*}" \
        -e APPLICATION_STORE="${SPRYKER_CURRENT_STORE}" \
        -e SPRYKER_CURRENT_REGION="${SPRYKER_CURRENT_REGION}" \
        -e SPRYKER_PIPELINE="${SPRYKER_PIPELINE}" \
        -e SSH_AUTH_SOCK="${SSH_AUTH_SOCK_IN_CLI}" \
        -e SPRYKER_XDEBUG_MODE_ENABLE="${SPRYKER_XDEBUG_MODE_ENABLE}" \
        -e SPRYKER_XDEBUG_ENABLE_FOR_CLI="${SPRYKER_XDEBUG_ENABLE_FOR_CLI}" \
        -e SPRYKER_TESTING_ENABLE_FOR_CLI="${SPRYKER_TESTING_ENABLE_FOR_CLI}" \
        -e COMPOSER_AUTH="${COMPOSER_AUTH}" \
        ${SPRYKER_PROJECT_NAME}_cli \
        bash -c 'bash ~/bin/cli.sh'
}

function Compose::verboseMode() {
    local output=''
    if [ "${SPRYKER_FILE_MODE}" == 'mount' ]; then
        output+="  DEVELOPMENT MODE  "
    fi
    if [ -n "${SPRYKER_TESTING_ENABLE}" ]; then
        output+="  TESTING MODE  "
    fi
    if [ -n "${SPRYKER_XDEBUG_ENABLE}" ] && [ -n "${SPRYKER_XDEBUG_MODE_ENABLE}" ]; then
        output+="  DEBUGGING MODE  "
    fi
    if [ -n "${output}" ]; then
        Console::warn "-->${output}"
    fi
    if [ -n "${SPRYKER_XDEBUG_ENABLE}" ] && [ -z "${SPRYKER_XDEBUG_MODE_ENABLE}" ]; then
        Console::error "Debugging is disabled in deploy.yml. Please, set ${INFO}deploy.yml: docker: debug: xdebug: enabled: true${WARN}, bootstrap and up to start debugging."
    fi
}

function Compose::command() {
    local -a composeFiles=()
    IFS=' ' read -r -a composeFiles <<< "$(Compose::getComposeFiles)"

    ${DOCKER_COMPOSE_SUBSTITUTE:-'docker-compose'} \
        --project-directory "${PROJECT_DIR}" \
        --project-name "${SPRYKER_PROJECT_NAME}" \
        "${composeFiles[@]}" \
        "${@}"
}

function Compose::SharedServices::command() {
    docker-compose \
        --project-directory "${PROJECT_DIR}" \
        --project-name "${SPRYKER_INTERNAL_PROJECT_NAME}_shared_services" \
        -f "${DEPLOYMENT_PATH}/../${SPRYKER_INTERNAL_PROJECT_NAME}/shared-services.docker-compose.yml" \
        "${@}"
}

function Compose::Gateway::command() {
    docker-compose \
        --project-directory "${PROJECT_DIR}" \
        --project-name "${SPRYKER_INTERNAL_PROJECT_NAME}_gateway" \
        -f "${DEPLOYMENT_PATH}/../${SPRYKER_INTERNAL_PROJECT_NAME}/gateway.docker-compose.yml" \
        "${@}"
}

# ---------------
function Compose::up() {

    local noCache=""
    local doBuild=""
    local doAssets=""
    local doData=""
    local doJobs=""

    for arg in "${@}"; do
        case "${arg}" in
            '--build')
                doBuild="--force"
                ;;
            '--assets')
                doAssets="--force"
                ;;
            '--data')
                doData="--force"
                ;;
            '--jobs')
                doJobs="--force"
                ;;
            '--no-cache')
                # TODO --no-cache flag. Ticket is necessary
                noCache="--no-cache"
                ;;
            *)
                Console::verbose "\nUnknown option ${INFO}${arg}${WARN} is acquired."
                ;;
        esac
    done

    Registry::Flow::runBeforeUp

    if [ "${doBuild}" = "--force" ]; then
      Compose::cleanSourceDirectory
    fi

    Images::buildApplication ${noCache} ${doBuild}
    Codebase::build ${noCache} ${doBuild}
    Assets::build ${noCache} ${doAssets}
    Images::buildFrontend ${noCache} ${doBuild}
    Compose::SharedServices::command up -d
    Compose::Gateway::command up -d

    Compose::run --build
    Compose::command restart ${SPRYKER_PROJECT_NAME}_frontend
    Compose::Gateway::command restart ${SPRYKER_INTERNAL_PROJECT_NAME}_gateway

    Registry::Flow::runAfterUp

    Data::load ${noCache} ${doData}
    Service::Scheduler::start '--force' ${noCache} ${doJobs}
}

function Compose::run() {
    Registry::Flow::runBeforeRun
    Console::verbose "${INFO}Running Spryker containers${NC}"
    Compose::command --compatibility up -d --quiet-pull "${@}"

# todo: env variable for each project
# todo: check
    if [ -n "${SPRYKER_TESTING_ENABLE}" ] && Service::isServiceExist scheduler; then
        Service::Scheduler::stop
    fi

    if [ -z "${SPRYKER_TESTING_ENABLE}" ]; then
      Compose::command --compatibility stop "${SPRYKER_PROJECT_NAME}_webdriver"
    fi

    # Note: Compose::run can be used for running only one container, e.g. CLI.
    Registry::Flow::runAfterRun
}

function Compose::performExec() {
    Compose::command exec "${@}"
}

function Compose::ps() {
    Compose::command ps "${@}"
}

function Compose::restart() {
    Console::verbose "${INFO}Restarting Spryker containers${NC}"
    Compose::stop
    Compose::run
}

function Compose::stop() {
    Console::verbose "${INFO}Stopping all containers${NC}"

    if [ ! -f "${DEPLOYMENT_DIR}/${ENABLED_FILENAME}" ]; then
      return
    fi

    local enabledProjects=($(Project::getListOfEnabledProjects))
    local enabledProjectsCount=${#enabledProjects[@]}

    if [ "${enabledProjectsCount}" == 1 ]; then
      Compose::command --profile ${SPRYKER_INTERNAL_PROJECT_NAME} --profile ${SPRYKER_PROJECT_NAME} stop
    else
      docker stop $(docker ps --filter "name=${SPRYKER_PROJECT_NAME}" --format="{{.ID}}")
    fi

    Registry::Flow::runAfterStop
}

function Compose::down()
{
    Console::verbose "${INFO}Stopping and removing all containers${NC}"
    Service::Scheduler::clean
    Compose::command down
    docker volume rm $(docker volume ls --filter "name=${SPRYKER_PROJECT_NAME}" --format="{{.Name}}")
    Registry::Flow::runAfterDown
}

function Compose::cleanVolumes() {
    Console::verbose "${INFO}Stopping and removing all Spryker containers and volumes${NC}"
    Compose::down
}

function Compose::cleanImages() {
    Compose::command rmi --force $(docker images --filter "reference=${SPRYKER_PROJECT_NAME}*" --format="{{.ID}}")
}

function Compose::cleanEverything() {
    Compose::cleanVolumes
    Compose::cleanImages
}

function Compose::runCliDependencyServices() {
    if [ "${TIDEWAYS_EXTENSION_ENABLED}" = "${TRUE}" ]; then
        Compose::run --no-deps tideways
    fi
}
# todo: another place
function Compose::cleanSourceDirectory() {
  local projectPath
  local srcGeneratedPath='src/Generated'

  projectPath=$(pwd)
  if [ -d "${projectPath}/${srcGeneratedPath}" ]; then
      rm -rf "${projectPath}/${srcGeneratedPath}"
  fi
}
