#!/bin/bash

Registry::addCommand "jobs" "Command::jobs"

Registry::Help::command -c "jobs start" "Generates and starts jobs."
Registry::Help::command -c "jobs stop" "Pauses all jobs."
Registry::Help::command -c "jobs clean" "Cleans all jobs."

function Command::jobs() {
    Compose::ensureRunning ${SPRYKER_INTERNAL_PROJECT_NAME}_scheduler

    local command=${1}
    shift || true

    case ${command} in
        ''|start)
            Service::Scheduler::start --force
            ;;
        stop)
            Service::Scheduler::stop
            ;;
        clean)
            Service::Scheduler::clean
            ;;
        *)
            Console::error "Unknown command ${INFO}${command}${WARN} is occurred."
            exit 1
            ;;
    esac

    return "${TRUE}"
}
