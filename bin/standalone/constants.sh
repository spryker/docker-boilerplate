#!/bin/bash

# shellcheck disable=SC2034
TRUE=0
FALSE=1

SPRYKER_DOCKER_SDK_INTERNAL_DEPLOYMENT_DIR='/data/deployment'

SPRYKER_INTERNAL_PROJECT_NAME='docker_sdk_spryker'
SPRYKER_SHARED_SERVICES_LIST=('gateway' 'broker' 'dashboard' 'database' 'key_value_store' 'kibana' 'mail_catcher' 'redis-gui' 'scheduler' 'search' 'session')

ENABLED_FILENAME='enabled'
PROJECT_PATH_FILENAME='project_path'

DOCKER_COMPOSE_GATEWAY_FILENAME='gateway.docker-compose.yml'
DOCKER_COMPOSE_SHARED_SERVICES_FILENAME='shared-services.docker-compose.yml'

DOCKER_COMPOSE_SHARED_SERVICES_DATA_FILENAME='docker-compose-shared-services-data.json'
DOCKER_COMPOSE_PROJECTS_DATA_FILENAME='docker-compose-projects-data.json'
DOCKER_COMPOSE_GATEWAY_DATA_FILENAME='docker-compose-gateway-data.json'
DOCKER_COMPOSE_SYNC_DATA_FILENAME='docker-compose-sync-data.json'
DOCKER_COMPOSE_REDIS_DATA_FILENAME='docker-compose-redis-data.json'

DOCKER_PUBLIC_NETWORK_NAME="${SPRYKER_INTERNAL_PROJECT_NAME}_public"
DOCKER_PRIVATE_NETWORK_NAME="${SPRYKER_INTERNAL_PROJECT_NAME}_private"
