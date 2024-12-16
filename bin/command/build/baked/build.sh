#!/usr/bin/env bash

Registry::addCommand "build" "Command::build"

Registry::Help::command -c "build" "[Deprecated for non-dev mode] Builds images, codebase and assets."
Registry::Help::command -c "build images" "[Deprecated for non-dev mode] Builds images and codebase."
Registry::Help::command -c "build assets" "[Deprecated for non-dev mode] Builds assets."

function Command::build() {

    Console::warn 'This command is deprecated for baked mount mode. Please, use up or export commands as well.'

    subCommand=${1}
    case ${subCommand} in
        images | image)
            Images::buildApplication --force
            Assets::build
            Images::buildFrontend --force
            ;;
        assets | asset)
            Assets::build --force
            Images::buildFrontend --force
            ;;
        cli)
            Images::buildApplication --force
            ;;   
        '')
            Images::buildApplication --force
            Assets::build --force
            Images::buildFrontend --force
            ;;
        *)
            Console::error "Unknown build target '${subCommand}' is occurred. No action." >&2
            exit 1
            ;;
    esac

    return "${TRUE}"
}
