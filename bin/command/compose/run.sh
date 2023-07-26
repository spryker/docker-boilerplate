#!/bin/bash

Registry::addCommand "run" "Command::run"
Registry::addCommand "start" "Command::run"

Registry::Help::command -c "run | start" "Runs Spryker containers."

function Command::run() {
#  todo: project name
    Compose::run
    Compose::command restart ${SPRYKER_PROJECT_NAME}_frontend
    Compose::Gateway::command restart ${SPRYKER_INTERNAL_PROJECT_NAME}_gateway

    Runtime::waitFor database
    Runtime::waitFor search
    Runtime::waitFor key_value_store

    return "${TRUE}"
}
