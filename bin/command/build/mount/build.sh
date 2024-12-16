#!/usr/bin/env bash

Registry::addCommand "build" "Command::build"

Registry::Help::command -c "build" "Builds images, codebase and assets."
Registry::Help::command -c "build images" "Builds images and codebase."
Registry::Help::command -c "build codebase" "Builds codebase."
Registry::Help::command -c "build assets" "Builds assets."

function Command::build() {
    subCommand=${1}
    case ${subCommand} in
        images | image)
            Images::buildApplication --force
            Codebase::build
            Assets::build
            Images::buildFrontend --force
            ;;
        cli)
            Images::buildApplication --force
            ;;    
        codebase | code)
            Codebase::build --force
            ;;
        assets | asset)
            Assets::build --force
            Images::buildFrontend --force
            ;;
        '')
            Images::buildApplication --force
            Codebase::build --force
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
