#!/bin/bash
Registry::Help::section "Paas | Cloud:"
Registry::Help::row "" "${HELP_DESC}The AWS CLI is ${WARN}required${NC} for Paas | Cloud Commands${NC}"
Registry::Help::row "" "${HELP_DESC}The AWS Session Manager plugin for the AWS CLI is ${WARN}required${NC} for Paas | Cloud Commands. See https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html${NC}"
Registry::Help::row "" "${HELP_DESC}AWS Access credentials are ${WARN}required${NC} for Paas | Cloud Commands. See https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html${NC}"
Registry::Help::section "Commands:"
Registry::addCommand "cloud" "Command::paas"
Registry::addCommand "paas" "Command::paas"

Registry::Help::command -s -c "paas | cloud environments" "Search the AWS Account for Paas Environments, and list them"
Registry::Help::command -s -c "paas | cloud service-details --environment=ENVIRONMENT_NAME" -a "service [database storage ..]" "List Paas Environment Service Details. See output from environments command. Services: database database-ro-replica storage search scheduler broker"
Registry::Help::command -s -c "paas | cloud create-tunnel --environment=ENVIRONMENT_NAME" -a "service [database storage ..]" "Create AWS SSM Tunnels to one or more Paas Environment Services. See output from environments command. Services: database database-ro-replica storage search scheduler broker"
Registry::Help::command -s -c "paas | cloud close-tunnel" -a "service [database storage ..]" "Close ALL Active AWS SSM Tunnels for Service. Services: database database-ro-replica storage search scheduler broker"
Registry::Help::command -s -c "paas | cloud tunnels" "List ALL Active AWS SSM Tunnels"

function Command::paas() {

    subCommand=${1}
    case ${subCommand} in
        environments)
            Paas::environments
            ;;
        service-details)
            Paas::service-details "${@}"
            ;;
        create-tunnel)
            Paas::create-tunnel "${@}"
            ;;
        close-tunnel)
            Paas::close-tunnel "${@}"
            ;;
        tunnels)
            Paas::tunnels
            ;;
        *)
            Console::error "Unknown option '${subCommand}'"
            exit 1
    esac

    return "${TRUE}"
}
