#!/bin/bash

function Project::enable() {
  touch ${DEPLOYMENT_PATH}/${ENABLED_FILENAME}
}

function Project::disable() {
  rm -f ${DEPLOYMENT_PATH}/${ENABLED_FILENAME}
}

Registry::Flow::addAfterRun "Project::enable"
Registry::Flow::addAfterUp "Project::enable"

Registry::Flow::addAfterStop "Project::disable"
Registry::Flow::addAfterDown "Project::disable"
