#!/bin/bash

function Project::bootstrap() {
  Project::bootstrap::_createProjectPathFile "${1}"
  Project::bootstrap::_createDockerNetworks
  Project::bootstrap::_createMutagenVolume
  Project::bootstrap::_copySharedData "${1}"
}

function Project::postBootstrap() {
  local sprykerInternalDeploymentPath="${DEPLOYMENT_DIR}/${SPRYKER_INTERNAL_PROJECT_NAME}"

  if [ ! -d "${sprykerInternalDeploymentPath}" ]; then
      mkdir "${sprykerInternalDeploymentPath}"
  fi

  Project::postBootstrap::_moveSharedData
  Project::postBootstrap::_moveComposeFiles
}

function Project::postBootstrap::_moveSharedData() {

  local sharedDataFilenameList=($(Project::_getSharedDataFilenameList))

  for sharedDataFilename in "${sharedDataFilenameList[@]}"; do
    local sharedDataFilePath

    sharedDataFilePath="${DESTINATION_DIR}/${sharedDataFilename}"
    destinationSharedDataFilePath="${DEPLOYMENT_DIR}/${SPRYKER_INTERNAL_PROJECT_NAME}/${sharedDataFilename}"

    if [ -f "${sharedDataFilePath}" ]; then
      mv "${sharedDataFilePath}" "${destinationSharedDataFilePath}"
    fi
  done
}

function Project::bootstrap::_createProjectPathFile() {
  local tmpDeploymentDir="${1}"

  echo "${SPRYKER_PROJECT_PATH}" > "${tmpDeploymentDir}/${PROJECT_PATH_FILENAME}"
}

function Project::postBootstrap::_moveComposeFiles() {
  mv "${DESTINATION_DIR}/${DOCKER_COMPOSE_FILENAME}" "${DEPLOYMENT_DIR}/${SPRYKER_INTERNAL_PROJECT_NAME}/${DOCKER_COMPOSE_FILENAME}"
}

function Project::bootstrap::_createDockerNetworks() {
  local publicNetworkId
  local privateNetworkId

  publicNetworkId=$(docker network ls --filter="name=${SPRYKER_INTERNAL_PROJECT_NAME}_${DOCKER_PUBLIC_NETWORK_NAME}" --format {{.ID}})
  privateNetworkId=$(docker network ls --filter="name=${SPRYKER_INTERNAL_PROJECT_NAME}_${DOCKER_PRIVATE_NETWORK_NAME}" --format {{.ID}})

  if [ -z "${publicNetworkId}" ] ; then
    docker network create "${SPRYKER_INTERNAL_PROJECT_NAME}_public" >/dev/null
  fi

  if [ -z "${privateNetworkId}" ] ; then
    docker network create "${SPRYKER_INTERNAL_PROJECT_NAME}_private" >/dev/null
  fi
}

function Project::bootstrap::_copySharedData() {
  local tmpDeploymentDir="${1}"
  local sharedDataFilenameList=($(Project::_getSharedDataFilenameList))

  for sharedDataFilename in "${sharedDataFilenameList[@]}"; do
    local sharedDataFilePath

    sharedDataFilePath="${DEPLOYMENT_DIR}/${SPRYKER_INTERNAL_PROJECT_NAME}/${sharedDataFilename}"

    if [ -f "${sharedDataFilePath}" ]; then
        cp "${sharedDataFilePath}" "${tmpDeploymentDir}"
    fi
  done
}

function Project::bootstrap::_createMutagenVolume() {
  local volumeName="${SPRYKER_PROJECT_NAME}_data_sync"
  local isVolumeExist

  isVolumeExist=$(docker network ls --filter="name=${SPRYKER_PROJECT_NAME}" --format {{.ID}})

  if [ -z "${isVolumeExist}" ] ; then
    docker volume create ${volumeName} >/dev/null
  fi
}

function Project::_getSharedDataFilenameList()
{
  local sharedDataFilenameList=(
    "${DOCKER_COMPOSE_SHARED_SERVICES_DATA_FILENAME}"
    "${DOCKER_COMPOSE_PROJECTS_DATA_FILENAME}"
    "${DOCKER_COMPOSE_GATEWAY_DATA_FILENAME}"
    "${DOCKER_COMPOSE_SYNC_DATA_FILENAME}"
    "${DOCKER_COMPOSE_REDIS_DATA_FILENAME}"
  )

  echo "${sharedDataFilenameList[*]}"
}
