#!/bin/bash

Registry::addCommand "prune" "Command::prune"
Registry::Help::command -c "prune [--f] [--a]" "Remove all docker data(images, volume, system and builder) and project artifacts."

function Command::prune() {
    local forceArg=''
    local artifactsArg=${FALSE}

    for ARG in "$@"; do
      if [ "${ARG}" == '--f' ]; then
        forceArg='-f'
      fi

      if [ "${ARG}" == '--a' ]; then
        artifactsArg=${TRUE}
      fi
    done

    Compose::command down
    sync clean # TODO deprecated, use Registry::Flow::addAfterDown in mounts
    Console::error "This will delete ALL docker images and volumes on the host."
    dropImages ${forceArg} # -a
    docker volume prune ${forceArg} # -a
    docker system prune -a ${forceArg}
    docker builder prune -a ${forceArg}

    if [ "${artifactsArg}" == "${TRUE}" ]; then
      Command::_prune_artifacts ${forceArg}
    fi

    return "${TRUE}"
}

function Command::_prune_artifacts() {
#    todo: per project
  local forceArg=${1}

  Command::_dropDirectory 'vendor/' ${forceArg}
  Command::_dropDirectory 'src/Generated/' ${forceArg}
  Command::_dropDirectory 'node_modules/' ${forceArg}
  Command::_dropDirectory 'public/*/assets/' ${forceArg}
}

function Command::_dropDirectory() {
#    todo: per project
  local directoryPath=${1}
  local forceArg=${2}
  local promptAnswer=${FALSE}
  local choice
  local dirSize=0B

  if [ "${forceArg}" == "-f" ]; then
    promptAnswer=${TRUE}
  else
    read -rp "Drop '${directoryPath}'? [y/N] " choice
    case "${choice}" in
    y | Y)
      promptAnswer=${TRUE}
      ;;
    n | N)
      promptAnswer=${FALSE}
      ;;
    *)
      promptAnswer=${FALSE}
      ;;
    esac
  fi

  if [ "${promptAnswer}" == "${TRUE}" ]; then
    if [ -n "$(ls -d ${directoryPath} 2> /dev/null)" ]; then
      dirSize=$(du -sch ${directoryPath} | grep total | cut -f -1)
    fi

    rm -rf ${directoryPath}
  fi

  echo "Total reclaimed space: ${dirSize}"
}
# todo: rename
function dropImages() {
  local forceArg=${1}
  local projects=($(Project::getProjectList))

  for projectName in "${projects[@]}" ; do
    local imageIdList=($(docker images "${projectName}_*" --format "{{.ID}}"))

    if [ -z "${imageIdList[*]}" ]; then
      continue
    fi

    local uniqImageIdList=($(for imageId in "${imageIdList[@]}"; do echo "${imageId}"; done | sort -u))

    docker image rm ${uniqImageIdList[*]} ${forceArg}
  done

  local nonameImageIdList=($(docker images -f 'dangling=true' -q))

  if [ -n "${nonameImageIdList[*]}" ]; then
    local uniqImageIdList=($(for imageId in "${nonameImageIdList[@]}"; do echo "${imageId}"; done | sort -u))
    docker image rm ${uniqImageIdList[*]} ${forceArg}
  fi

  docker images --filter "reference=spryker_docker_sdk" --format "{{.ID}}" | xargs ${XARGS_NO_RUN_IF_EMPTY} docker rmi -f
}
