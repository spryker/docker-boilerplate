#!/bin/bash

Registry::addCommand "envs" "Command::environments"
Registry::addCommand "environments" "Command::environments"

Registry::Help::command -c "environments" "Shows iformation about each environment."

function Command::environments() {
  local tableSeparator="-------------"
  local projectDeploymentPathList=($(find "${DEPLOYMENT_DIR}/.." -maxdepth 1 -type d))

  echo "Environments:"
  echo "${tableSeparator}"

  for projectDeploymentPath in "${projectDeploymentPathList[@]}" ; do
    local projectName=$(basename "${projectDeploymentPath}")
    if [ "${projectName}" == "${SPRYKER_INTERNAL_PROJECT_NAME}" ] || [ "${projectName}" == ".." ]; then
        continue
    fi

    local projectPath=$(cat "${projectDeploymentPath}/${PROJECT_PATH_FILENAME}")
    local projectStatus=$([ -f ${projectDeploymentPath}/enabled ] && echo "Enabled" || echo "Disabled")

    echo "Project Name: ${projectName}"
    echo "Project Path: ${projectPath}"
    echo "Project Status: ${projectStatus}"
    echo "${tableSeparator}"
  done
}

