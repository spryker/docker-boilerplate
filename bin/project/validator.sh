#!/bin/bash

function Project::validate() {
  Project::_projectNameValidation
}

function Project::_projectNameValidation() {
  if [ "${SPRYKER_PROJECT_NAME}" == "${SPRYKER_INTERNAL_PROJECT_NAME}" ]; then
    Console::error "\nProject name ${INFO}${SPRYKER_INTERNAL_PROJECT_NAME}${WARN} is internal name. Please change project name to another one."
    exit 1
  fi

  if [ -d ${DESTINATION_DIR} ] ; then
    local projectPath
    projectPath=$(cat "${DESTINATION_DIR}/${PROJECT_PATH_FILENAME}")

    if [ "${projectPath}" != "${SPRYKER_PROJECT_PATH}" ]; then
      Console::error "\nProject name ${INFO}${SPRYKER_PROJECT_NAME}${WARN} is used with spryker project(${INFO}${projectPath}${WARN}). Please change project name."
      exit 1
    fi
  fi
}
