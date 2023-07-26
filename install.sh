#!/bin/bash

readonly DOCKER_SDK_PATH="${HOME}/.docker-sdk"
readonly DOCKER_SDK_REPO="git@github.com:spryker/docker-sdk.git"

function cleanUpOlderVersion() {
  rm -rf "${DOCKER_SDK_PATH}"
}

function clone() {
  git clone "${DOCKER_SDK_REPO}" "${DOCKER_SDK_PATH}"
}

function install() {
  cleanUpOlderVersion
  clone
}

install
