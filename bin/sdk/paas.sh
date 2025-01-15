#!/bin/bash

# shellcheck disable=SC2155

require aws jq tr nc awk shuf sed grep

# check if the user is authenticated with AWS
function Paas::checkAwsSessionCredentials() {
    AWS_ACCOUNT=$(AWS_REGION=eu-central-1 aws sts get-caller-identity --output text --no-cli-pager --query "Account")

    EXITCODE=$?
    if [ "${EXITCODE}" -ne "0" ]; then
        Console::error "${WARN}AWS session credentials is not set${NC}"
        exit 1
    fi

    if ! [[ ${FUNCNAME[@]} =~ "Paas::getEnvironmentsCacheFile" ]]; then
        Console::info "${INFO}You are authenticated with AWS Account${NC} ${GREEN}${AWS_ACCOUNT}${NC}"
    fi

    return "${TRUE}"
}

# get the AWS Region in which the environment exist
function Paas::get-environment-region() {
    local ENVIRONMENT=$1

    Paas::getEnvironmentsCacheFile
    ENVIRONMENT_REGION=$(grep "${ENVIRONMENT}:" ${ENVIRONMENT_TMP_FILE} | cut -d ":" -f2)

    return "${TRUE}"
}

# verify environment exists with in AWS Account - and the cache file
function Paas::verify-environment-exists() {
    Paas::getEnvironmentsCacheFile

    local ENVIRONMENT=$1

    ENVIRONMENT_RESULT=$(grep -Ec "^${ENVIRONMENT}:" ${ENVIRONMENT_TMP_FILE} || true)

    if [ "${ENVIRONMENT_RESULT}" -eq 0 ]; then
        Console::error "${WARN}Environment ${ENVIRONMENT} does not exist in the AWS account ${AWS_ACCOUNT}${NC}"
        exit 1
    fi

    return "${TRUE}"
}

# get rhe environments cache file
# cache file is used to sync PaaS environments to prevent constant lookups
function Paas::getEnvironmentsCacheFile() {
    ENVIRONMENT_TMP_FILE=/tmp/${AWS_ACCOUNT}_spryker_paas_environments.tmp
    if [ ! -f ${ENVIRONMENT_TMP_FILE} ]; then
        Console::info "${INFO}Creating environments cache file${NC}"
        Paas::createEnvironmentsCacheFile ${ENVIRONMENT_TMP_FILE}

        # execute Paas::environments commands only if it is not the original calling function
        # used to populate cache file with environments, and regions
        if ! [[ ${FUNCNAME[@]} =~ "Paas::environments" ]]; then
            Paas::environments
        fi
    fi

    return "${TRUE}"
}

# create the cache file
function Paas::createEnvironmentsCacheFile() {
    local ENVIRONMENT_TMP_FILE=$1
    touch ${ENVIRONMENT_TMP_FILE}

    return "${TRUE}"
}

# update the cache file with PaaS environments
Paas::writeEnvironmentsCacheFile() {
    # clear existing environments regions cache
    truncate -s 0 ${ENVIRONMENT_TMP_FILE}

    # generate environments regions cache
    for ENTITY in "${ENVIRONMENTS_AND_REGIONS[@]}"; do
        # split ENTITY by AWS Region, and ECS Cluster Name (Environment Name)
        ENTITY_ENVIRONMENT_NAME=$(head -1 <<<"${ENTITY}" | cut -d ',' -f2)
        ENTITY_REGION=$(head -1 <<<"${ENTITY}" | cut -d ',' -f1)

        Console::log "${NC}Found environment ${GREEN}${ENTITY_ENVIRONMENT_NAME}${NC} ${NC}in AWS region ${GREEN}${ENTITY_REGION}${NC}"

        echo "${ENTITY_ENVIRONMENT_NAME}:${ENTITY_REGION}" >> ${ENVIRONMENT_TMP_FILE}
    done

    # write environments to tmp file (cache file)
    Console::info "${INFO}Environments cache file ${ENVIRONMENT_TMP_FILE}${NC}"

    return "${TRUE}"
}


# search for a random EC2 instance to use as a Jump Host
function Paas::discoverRandomEc2JumpInstance() {
    local ENVIRONMENT=$1

    # get environment region
    Paas::get-environment-region "${ENVIRONMENT}"

    Console::log "${INFO}Selecting random EC2 instance jump host within the environment${NC} ${GREEN}${ENVIRONMENT}${NC}"

    EC2_INSTANCE_ID=$(aws ec2 describe-instances --region ${ENVIRONMENT_REGION} --filters "Name=tag:Name,Values=*${ENVIRONMENT}-ecs-autoscaled*" 'Name=instance-state-name,Values=running' --output text --no-cli-pager --query "Reservations[*].Instances[*].[InstanceId]" | shuf -n 1 || true)

    if [ "${EC2_INSTANCE_ID}" == "None" ] || [ "${EC2_INSTANCE_ID}" == "" ]; then
        Console::error "${WARN}Could not find EC2 instance${NC}"
        exit 1
    else
        Console::log "${INFO}Selected EC2 instance${NC} ${GREEN}${EC2_INSTANCE_ID}${NC}"
        return "${TRUE}"
    fi
}

# print out Paas environment and AWS Region
function Paas::environments() {
    # check for valid AWS Session
    Paas::checkAwsSessionCredentials

    Console::log "${INFO}This operation is currently searching the AWS account for Paas environments (All AWS regions)${NC}"
    Console::log ""

    # the below call is executed asynchronusly
    # we lookup all the available regions in the aws account, and for each region, we look for any ecs clusters (environments)
    ENVIRONMENTS_AND_REGIONS=( $(for region in $(AWS_REGION=eu-central-1 aws ec2 describe-regions --output text --no-cli-pager | cut -f4); do aws ecs list-clusters --region="${region}" --output text --no-cli-pager --query "clusterArns[*]" | sed 's/\t\t*/\n/g' | cut -d ':' -f4,6 | grep -v 'scheduler' | sed 's/:cluster\//,/' & done) )

    if [ ${#ENVIRONMENTS_AND_REGIONS[@]} -eq 0 ]; then
        Console::error "${WARN}Could not find any environments!${NC}"
        exit 1
    fi

    # write environments and their regions to a cache file
    Paas::getEnvironmentsCacheFile
    Paas::writeEnvironmentsCacheFile

    return "${TRUE}"
}

# fetch service details
function Paas::service-details() {
    # check for valid AWS Session
    Paas::checkAwsSessionCredentials

   # check if environment is set
    local ENVIRONMENT=${FALSE}
    for arg in "${@}"; do
        case "${arg}" in
            --environment=*)
                ENVIRONMENT="${arg#*=}"

                Paas::verify-environment-exists ${ENVIRONMENT}
                ;;
        esac
    done

    # enforce environment flag
    if [ "${ENVIRONMENT}" == "${FALSE}" ]; then
        Console::error "${WARN}You need to specify an environment with --environment=ENVIRONMENT_NAME${NC}"
        exit 1
    fi

    # get environment region
    Paas::get-environment-region ${ENVIRONMENT}
    Console::info "${INFO}Target environment ${NC}${GREEN}${ENVIRONMENT}${NC}${INFO} AWS region ${NC}${GREEN}${ENVIRONMENT_REGION}${NC}"

    # database, storage, search, scheduler, broker
    for arg in "${@}"; do
        case "${arg}" in
            'database')
                Console::info "${INFO}Fetching ${GREEN}${arg}${NC} ${INFO}details${NC}"

                # SSM parameters
                SEARCH_PATTERN="SPRYKER_DB"
                aws ssm --region ${ENVIRONMENT_REGION} get-parameters-by-path --path "/${ENVIRONMENT}/codebuild/base_task_definition/" --recursive --with-decryption --output json --no-cli-pager | jq -r --arg SEARCH_PATTERN "$SEARCH_PATTERN" '.Parameters[] | select(.Name | contains($SEARCH_PATTERN)) | "\(.Name)=\(.Value)"' | sed 's/^.*SPRYKER/SPRYKER/'
                ;;
            'database-ro-replica')
                # adding RO Replica if we find one. These details do not exist within the Parameter Store
                Console::info "${INFO}Fetching ${GREEN}${arg}${NC}${INFO} details. Only for ${GREEN}PRODUCTION${NC}${INFO} environments. Use the credentials for the ${GREEN}database${NC} ${INFO}to connect${NC}"

                Paas::check-read-replica-exists

                if [ "${SPRYKER_DB_RO_REPLICA_EXIST}" != "${FALSE}" ]; then
                    SPRYKER_DB_RO_REPLICA_DETAILS=$(aws rds describe-db-instances --region ${ENVIRONMENT_REGION} --db-instance-identifier "${ENVIRONMENT}"-ro-replica-0 --output text --no-cli-pager --query "DBInstances[*].Endpoint[].[Address,Port]" | sed 's/\t\t*/\n/g')
                    SPRYKER_DB_RO_REPLICA_HOST=$(head -1 <<<"${SPRYKER_DB_RO_REPLICA_DETAILS}" | tail -1)
                    SPRYKER_DB_RO_REPLICA_PORT=$(head -2 <<<"${SPRYKER_DB_RO_REPLICA_DETAILS}" | tail -1)

                    echo "SPRYKER_DB_RO_REPLICA_HOST=${SPRYKER_DB_RO_REPLICA_HOST}"
                    echo "SPRYKER_DB_RO_REPLICA_PORT=${SPRYKER_DB_RO_REPLICA_PORT}"
                else
                    echo "READ-REPLICA not found."
                fi
                ;;
            'storage')
                Console::info "${INFO}Fetching ${GREEN}${arg}${NC} ${INFO}details${NC}"
                
                # SSM parameters
                SEARCH_PATTERNS="SPRYKER_KEY_VALUE SPRYKER_SESSION"
                for SEARCH_PATTERN in $SEARCH_PATTERNS; do 
                    aws ssm --region ${ENVIRONMENT_REGION} get-parameters-by-path --path "/${ENVIRONMENT}/codebuild/base_task_definition/" --recursive --with-decryption --output json --no-cli-pager | jq -r --arg SEARCH_PATTERN "$SEARCH_PATTERN" '.Parameters[] | select(.Name | contains($SEARCH_PATTERN)) | "\(.Name)=\(.Value)"' | sed 's/^.*SPRYKER/SPRYKER/';
                done
                ;;
            'search')
                Console::info "${INFO}Fetching ${GREEN}${arg}${NC} ${INFO}details${NC}"

                # SSM parameters
                SEARCH_PATTERN="SPRYKER_SEARCH"
                aws ssm --region ${ENVIRONMENT_REGION} get-parameters-by-path --path "/${ENVIRONMENT}/codebuild/base_task_definition/" --recursive --with-decryption --output json --no-cli-pager | jq -r --arg SEARCH_PATTERN "$SEARCH_PATTERN" '.Parameters[] | select(.Name | contains($SEARCH_PATTERN)) | "\(.Name)=\(.Value)"' | sed 's/^.*SPRYKER/SPRYKER/'
                ;;
            'scheduler')
                Console::info "${INFO}Fetching ${GREEN}${arg}${NC} ${INFO}details${NC}"

                # SSM parameters
                SEARCH_PATTERN="SPRYKER_SCHEDULER"
                aws ssm --region ${ENVIRONMENT_REGION} get-parameters-by-path --path "/${ENVIRONMENT}/codebuild/base_task_definition/" --recursive --with-decryption --output json --no-cli-pager | jq -r --arg SEARCH_PATTERN "$SEARCH_PATTERN" '.Parameters[] | select(.Name | contains($SEARCH_PATTERN)) | "\(.Name)=\(.Value)"' | sed 's/^.*SPRYKER/SPRYKER/'
                ;;
            'broker')
                Console::info "${INFO}Fetching ${GREEN}${arg}${NC} ${INFO}details${NC}"

                # SSM parameters
                SEARCH_PATTERN="SPRYKER_BROKER"
                aws ssm --region ${ENVIRONMENT_REGION} get-parameters-by-path --path "/${ENVIRONMENT}/codebuild/base_task_definition/" --recursive --with-decryption --output json --no-cli-pager | jq -r --arg SEARCH_PATTERN "$SEARCH_PATTERN" '.Parameters[] | select(.Name | contains($SEARCH_PATTERN)) | "\(.Name)=\(.Value)"' | sed 's/^.*SPRYKER/SPRYKER/'
                ;;
            *)
                Console::verbose "\nUnknown service ${INFO}${arg}${WARN}."
                ;;
        esac
    done

    return "${TRUE}"
}

# create a SSM tunnel to a service
function Paas::create-tunnel() {
    # check for valid AWS Session
    Paas::checkAwsSessionCredentials

    # check if environment is set
    local ENVIRONMENT=${FALSE}
    for arg in "${@}"; do
        case "${arg}" in
            --environment=*)
                ENVIRONMENT="${arg#*=}"

                Paas::verify-environment-exists ${ENVIRONMENT}
                ;;
        esac
    done

    # enforce environment flag
    if [ "${ENVIRONMENT}" == "${FALSE}" ]; then
        Console::error "${WARN}You need to specify an environment with --environment=ENVIRONMENT_NAME${NC}"
        exit 1
    fi

    # get environment region
    Paas::get-environment-region ${ENVIRONMENT}
    Console::info "${INFO}Target environment ${NC}${GREEN}${ENVIRONMENT}${NC}${INFO} AWS region ${NC}${GREEN}${ENVIRONMENT_REGION}${NC}"

    # fetch all Service Connection Parameters to save time
    Console::log "${INFO}Fetching service connection parameters${NC}"

    # SSM Service Connection Parameters 
    # create array of search patterns
    SEARCH_PATTERNS="SPRYKER_DB_HOST SPRYKER_DB_PORT SPRYKER_KEY_VALUE_STORE_HOST SPRYKER_KEY_VALUE_STORE_PORT SPRYKER_SEARCH_HOST SPRYKER_SEARCH_PORT SPRYKER_SCHEDULER_HOST SPRYKER_SCHEDULER_PORT SPRYKER_BROKER_API_HOST SPRYKER_BROKER_API_PORT"

    # create SSM Service Connection Parameters string SERVICE_CONNECTION_PARAMETERS from SEARCH_PATTERNS array
    Paas::create-search-string

    # do SSM call and set service connection variables
    SERVICE_CONNECTION_PARAMETERS=( $(aws ssm get-parameters --region ${ENVIRONMENT_REGION} --names ${SEARCH_STRING_RESULT} --with-decryption --no-cli-pager | jq -r '.Parameters[] | "\(.Name)=\(.Value)"' | sed 's/^.*SPRYKER/SPRYKER/') )
    for SERVICE_CONNECTION_PARAMETER in "${SERVICE_CONNECTION_PARAMETERS[@]}"; do
        declare ${SERVICE_CONNECTION_PARAMETER};
    done

    # fetch details for RDS RO REPLICA if it exists
    Paas::check-read-replica-exists

    if [ "${SPRYKER_DB_RO_REPLICA_EXIST}" != "${FALSE}" ]; then
        SPRYKER_DB_RO_REPLICA_DETAILS=$(aws rds describe-db-instances --region ${ENVIRONMENT_REGION} --db-instance-identifier "${ENVIRONMENT}"-ro-replica-0 --output text --no-cli-pager --query "DBInstances[*].Endpoint[].[Address,Port]" | sed 's/\t\t*/\n/g')
        SPRYKER_DB_RO_REPLICA_HOST=$(head -1 <<<"${SPRYKER_DB_RO_REPLICA_DETAILS}" | tail -1)
        SPRYKER_DB_RO_REPLICA_PORT=$(head -2 <<<"${SPRYKER_DB_RO_REPLICA_DETAILS}" | tail -1)
    fi

    # discover random EC2 jump instance
    Paas::discoverRandomEc2JumpInstance "${ENVIRONMENT}"

    # database, storage, search, scheduler, broker
    MAX_WAIT=60
    for arg in "${@}"; do
        case "${arg}" in
            'database')
                Console::info "${INFO}Establishing tunnel to ${NC}${GREEN}${arg}${NC} ${INFO}service${NC}"

                Paas::get-open-port ${arg}

                # create tunnel
                aws ssm start-session --region ${ENVIRONMENT_REGION} \
                --target ${EC2_INSTANCE_ID} \
                --document-name AWS-StartPortForwardingSessionToRemoteHost \
                --parameters host="${SPRYKER_DB_HOST}",portNumber="${SPRYKER_DB_PORT}",localPortNumber="${TUNNEL_LOCAL_PORT}" > /tmp/spryker-tunnel-${arg}.log & pid=$!
                
                # confirm tunnel has started
                TUNNEL_CREATE_ATTEMPT=0
                until grep "Waiting for connections" /tmp/spryker-tunnel-${arg}.log
                do
                    sleep 1

                    if [[ ${TUNNEL_CREATE_ATTEMPT} -eq ${MAX_WAIT}  ]]
                    then
                        Console::error "${WARN}Could not establish conection. See /tmp/spryker-tunnel-${arg}.log for more details.${NC}"
                        exit 1
                    fi
                    ((TUNNEL_CREATE_ATTEMPT++))
                done

                if [ "${pid}" != "${FALSE}" ]; then
                    Console::log "${INFO}Remote Endpoint:${NC} ${GREEN}${SPRYKER_DB_HOST}${NC} ${INFO}Remote Port:${NC} ${GREEN}${SPRYKER_DB_PORT}${NC} ${INFO}Local Endpoint:${NC} ${GREEN}localhost${NC} ${INFO}Local Port:${NC} ${GREEN}${TUNNEL_LOCAL_PORT}${NC}"
                fi

                ;;
            'database-ro-replica')
                Console::info "${INFO}Establishing tunnel to ${NC}${GREEN}${arg} RO REPLICA${NC} ${INFO}service. Only for ${GREEN}PRODUCTION${NC}${INFO} environments. Use the credentials for the ${GREEN}database${NC} ${INFO}to connect${NC}"

                # check if READ-REPLICA exists
                if [ "${SPRYKER_DB_RO_REPLICA_EXIST}" == "${FALSE}" ]; then
                    echo "READ-REPLICA not found."
                    continue
                fi

                Paas::get-open-port ${arg}

                # create tunnel
                aws ssm start-session --region ${ENVIRONMENT_REGION} \
                --target ${EC2_INSTANCE_ID} \
                --document-name AWS-StartPortForwardingSessionToRemoteHost \
                --parameters host="${SPRYKER_DB_RO_REPLICA_HOST}",portNumber="${SPRYKER_DB_RO_REPLICA_PORT}",localPortNumber="${TUNNEL_LOCAL_PORT}" > /tmp/spryker-tunnel-${arg}.log & pid=$!

                # confirm tunnel has started
                TUNNEL_CREATE_ATTEMPT=0
                until grep "Waiting for connections" /tmp/spryker-tunnel-${arg}.log
                do
                    sleep 1

                    if [[ ${TUNNEL_CREATE_ATTEMPT} -eq ${MAX_WAIT}  ]]
                    then
                        Console::error "${WARN}Could not establish conection. See /tmp/spryker-tunnel-${arg}.log for more details.${NC}"
                        exit 1
                    fi
                    ((TUNNEL_CREATE_ATTEMPT++))
                done

                if [ "${pid}" != "${FALSE}" ]; then
                    Console::log "${INFO}Remote Endpoint:${NC} ${GREEN}${SPRYKER_DB_RO_REPLICA_HOST}${NC} ${INFO}Remote Port:${NC} ${GREEN}${SPRYKER_DB_RO_REPLICA_PORT}${NC} ${INFO}Local Endpoint:${NC} ${GREEN}localhost${NC} ${INFO}Local Port:${NC} ${GREEN}${TUNNEL_LOCAL_PORT}${NC}"
                fi

                ;;
            'storage')
                Console::info "${INFO}Establishing tunnel to ${NC}${GREEN}${arg}${NC} ${INFO}service${NC}"

                Paas::get-open-port ${arg}

                # create tunnel
                aws ssm start-session --region ${ENVIRONMENT_REGION} \
                --target ${EC2_INSTANCE_ID} \
                --document-name AWS-StartPortForwardingSessionToRemoteHost \
                --parameters host="${SPRYKER_KEY_VALUE_STORE_HOST}",portNumber="${SPRYKER_KEY_VALUE_STORE_PORT}",localPortNumber="${TUNNEL_LOCAL_PORT}" > /tmp/spryker-tunnel-${arg}.log & pid=$!
                
                # confirm tunnel has started
                TUNNEL_CREATE_ATTEMPT=0
                until grep "Waiting for connections" /tmp/spryker-tunnel-${arg}.log
                do
                    sleep 1

                    if [[ ${TUNNEL_CREATE_ATTEMPT} -eq ${MAX_WAIT}  ]]
                    then
                        Console::error "${WARN}Could not establish conection. See /tmp/spryker-tunnel-${arg}.log for more details.${NC}"
                        exit 1
                    fi
                    ((TUNNEL_CREATE_ATTEMPT++))
                done

                if [ "${pid}" != "${FALSE}" ]; then
                    Console::log "${INFO}Remote Endpoint:${NC} ${GREEN}${SPRYKER_KEY_VALUE_STORE_HOST}${NC} ${INFO}Remote Port:${NC} ${GREEN}${SPRYKER_KEY_VALUE_STORE_PORT}${NC} ${INFO}Local Endpoint:${NC} ${GREEN}localhost${NC} ${INFO}Local Port:${NC} ${GREEN}${TUNNEL_LOCAL_PORT}${NC}"
                fi

                ;;
            'search')
                Console::info "${INFO}Establishing tunnel to ${NC}${GREEN}${arg}${NC} ${INFO}service${NC}"

                Paas::get-open-port ${arg}

                # create tunnel
                aws ssm start-session --region ${ENVIRONMENT_REGION} \
                --target ${EC2_INSTANCE_ID} \
                --document-name AWS-StartPortForwardingSessionToRemoteHost \
                --parameters host="${SPRYKER_SEARCH_HOST}",portNumber="${SPRYKER_SEARCH_PORT}",localPortNumber="${TUNNEL_LOCAL_PORT}" > /tmp/spryker-tunnel-${arg}.log & pid=$!
                
                # confirm tunnel has started
                TUNNEL_CREATE_ATTEMPT=0
                until grep "Waiting for connections" /tmp/spryker-tunnel-${arg}.log
                do
                    sleep 1

                    if [[ ${TUNNEL_CREATE_ATTEMPT} -eq ${MAX_WAIT}  ]]
                    then
                        Console::error "${WARN}Could not establish conection. See /tmp/spryker-tunnel-${arg}.log for more details.${NC}"
                        exit 1
                    fi
                    ((TUNNEL_CREATE_ATTEMPT++))
                done

                if [ "${pid}" != "${FALSE}" ]; then
                    Console::log "${INFO}Remote Endpoint:${NC} ${GREEN}${SPRYKER_SEARCH_HOST}${NC} ${INFO}Remote Port:${NC} ${GREEN}${SPRYKER_SEARCH_PORT}${NC} ${INFO}Local Endpoint:${NC} ${GREEN}localhost${NC} ${INFO}Local Port:${NC} ${GREEN}${TUNNEL_LOCAL_PORT}${NC}"
                fi
                
                ;;
            'scheduler')
                Console::info "${INFO}Establishing tunnel to ${NC}${GREEN}${arg}${NC} ${INFO}service${NC}"

                Paas::get-open-port ${arg}

                # create tunnel
                aws ssm start-session --region ${ENVIRONMENT_REGION} \
                --target ${EC2_INSTANCE_ID} \
                --document-name AWS-StartPortForwardingSessionToRemoteHost \
                --parameters host="${SPRYKER_SCHEDULER_HOST}",portNumber="${SPRYKER_SCHEDULER_PORT}",localPortNumber="${TUNNEL_LOCAL_PORT}" > /tmp/spryker-tunnel-${arg}.log & pid=$!
                
                # confirm tunnel has started
                TUNNEL_CREATE_ATTEMPT=0
                until grep "Waiting for connections" /tmp/spryker-tunnel-${arg}.log
                do
                    sleep 1

                    if [[ ${TUNNEL_CREATE_ATTEMPT} -eq ${MAX_WAIT}  ]]
                    then
                        Console::error "${WARN}Could not establish conection. See /tmp/spryker-tunnel-${arg}.log for more details.${NC}"
                        exit 1
                    fi
                    ((TUNNEL_CREATE_ATTEMPT++))
                done

                if [ "${pid}" != "${FALSE}" ]; then
                    Console::log "${INFO}Remote Endpoint:${NC} ${GREEN}${SPRYKER_SCHEDULER_HOST}${NC} ${INFO}Remote Port:${NC} ${GREEN}${SPRYKER_SCHEDULER_PORT}${NC} ${INFO}Local Endpoint:${NC} ${GREEN}localhost${NC} ${INFO}Local Port:${NC} ${GREEN}${TUNNEL_LOCAL_PORT}${NC}"
                fi
                
                ;;
            'broker')
                Console::info "${INFO}Establishing tunnel to ${NC}${GREEN}${arg}${NC} ${INFO}service${NC}"
                
                Paas::get-open-port ${arg}

                # creating tunnel
                aws ssm start-session --region ${ENVIRONMENT_REGION} \
                --target ${EC2_INSTANCE_ID} \
                --document-name AWS-StartPortForwardingSessionToRemoteHost \
                --parameters host="${SPRYKER_BROKER_API_HOST}",portNumber="${SPRYKER_BROKER_API_PORT}",localPortNumber="${TUNNEL_LOCAL_PORT}" > /tmp/spryker-tunnel-${arg}.log & pid=$!
                
                # confirm tunnel has started
                TUNNEL_CREATE_ATTEMPT=0
                until grep "Waiting for connections" /tmp/spryker-tunnel-${arg}.log
                do
                    sleep 1

                    if [[ ${TUNNEL_CREATE_ATTEMPT} -eq ${MAX_WAIT}  ]]
                    then
                        Console::error "${WARN}Could not establish conection. See /tmp/spryker-tunnel-${arg}.log for more details.${NC}"
                        exit 1
                    fi
                    ((TUNNEL_CREATE_ATTEMPT++))
                done

                if [ "${pid}" != "${FALSE}" ]; then
                    Console::info "${INFO}Remote Endpoint:${NC} ${GREEN}${SPRYKER_BROKER_API_HOST}${NC} ${INFO}Remote Port:${NC} ${GREEN}${SPRYKER_BROKER_API_PORT}${NC} ${INFO}Local Endpoint:${NC} ${GREEN}localhost${NC} ${INFO}Local Port:${NC} ${GREEN}${TUNNEL_LOCAL_PORT}${NC}"
                fi
                
                ;;
            *)
                Console::verbose "\nUnknown service ${INFO}${arg}${WARN}."
                ;;
        esac
    done

    return "${TRUE}"
}

# close all SSM tunnels to a service
function Paas::close-tunnel() {
    # database, storage, search, scheduler, broker
    for arg in "${@}"; do
        case "${arg}" in
            'database')
                Console::info "${INFO}Closing tunnel to service ${GREEN}${arg}${NC}"

                START=5000
                END=5009

                for (( port=${START}; port<=${END}; port++ ))
                do
                    Paas::close-busy-port ${port}
                done

                ;;
            'database-ro-replica')
                Console::info "${INFO}Closing tunnel to service ${GREEN}${arg}${NC}"

                START=5010
                END=5019

                for (( port=${START}; port<=${END}; port++ ))
                do
                    Paas::close-busy-port ${port}
                done

                ;;
            'storage')
                Console::info "${INFO}Closing tunnel to service ${GREEN}${arg}${NC}"
                
                START=5020
                END=5029

                for (( port=${START}; port<=${END}; port++ ))
                do
                    Paas::close-busy-port ${port}
                done

                ;;
            'search')
                Console::info "${INFO}Closing tunnel to service ${GREEN}${arg}${NC}"
                
                START=5030
                END=5039

                for (( port=${START}; port<=${END}; port++ ))
                do
                    Paas::close-busy-port ${port}
                done

                ;;
            'scheduler')
                Console::info "${INFO}Closing tunnel to service ${GREEN}${arg}${NC}"
                
                START=5040
                END=5049

                for (( port=${START}; port<=${END}; port++ ))
                do
                    Paas::close-busy-port ${port}
                done

                ;;
            'broker')
                Console::info "${INFO}Closing tunnel to service ${GREEN}${arg}${NC}"

                START=5050
                END=5059

                for (( port=${START}; port<=${END}; port++ ))
                do
                    Paas::close-busy-port ${port}
                done

                ;;
            *)
                Console::verbose "\nUnknown service ${INFO}${arg}${WARN}."
                ;;
        esac
    done

    return "${TRUE}"
}

# list all open SSM tunnels
function Paas::tunnels() {
    ps aux |grep -E 'aws ssm start-session.*' |grep -vE "grep"
}

# utility function creating a SSM Parameter Store search pattern for quicker searching
function Paas::create-search-string() {
    local SEARCH_STRING=""
    for SEARCH_PATTERN in ${SEARCH_PATTERNS[@]}; do
        if [[ -z "${SEARCH_STRING}" ]]; then
            SEARCH_STRING+="/${ENVIRONMENT}/codebuild/base_task_definition/${SEARCH_PATTERN}"
        else
            SEARCH_STRING+=" /${ENVIRONMENT}/codebuild/base_task_definition/${SEARCH_PATTERN}"
        fi
    done

    SEARCH_STRING_RESULT=${SEARCH_STRING}

    return "${TRUE}"
}

# identify open ports to use for a SSM tunnel
function Paas::get-open-port() {
    local SERVICE=$1

    # database, storage, search, scheduler, broker
    case "${SERVICE}" in
        'database')
            START=5000
            END=5009
            TUNNEL_LOCAL_PORT=${FALSE}

            for (( port=${START}; port<=${END}; port++ ))
            do
                Paas::check-open-port ${port}
                if [ "${TUNNEL_LOCAL_PORT}" != "${FALSE}" ]; then
                    break
                fi
                if [ "${TUNNEL_LOCAL_PORT}" == "${FALSE}" ] && [ $port == $END ]; then
                    echo "No available port found. Close some tunnels with the close-tunnel command"
                    exit 1
                fi
            done

            return "${TRUE}"
            ;;
        'database-ro-replica')
            START=5010
            END=5019
            TUNNEL_LOCAL_PORT=${FALSE}
            
            for (( port=${START}; port<=${END}; port++ ))
            do
                Paas::check-open-port ${port}
                if [ "${TUNNEL_LOCAL_PORT}" != "${FALSE}" ]; then
                    break
                fi
                if [ "${TUNNEL_LOCAL_PORT}" == "${FALSE}" ] && [ $port == $END ]; then
                    echo "No available port found. Close some tunnels with the close-tunnel command"
                    exit 1
                fi
            done

            return "${TRUE}"
            ;;
        'storage')
            START=5020
            END=5029
            TUNNEL_LOCAL_PORT=${FALSE}
            
            for (( port=${START}; port<=${END}; port++ ))
            do
                Paas::check-open-port ${port}
                if [ "${TUNNEL_LOCAL_PORT}" != "${FALSE}" ]; then
                    break
                fi
                if [ "${TUNNEL_LOCAL_PORT}" == "${FALSE}" ] && [ $port == $END ]; then
                    echo "No available port found. Close some tunnels with the close-tunnel command"
                    exit 1
                fi
            done

            return "${TRUE}"
            ;;
        'search')
            START=5030
            END=5039
            TUNNEL_LOCAL_PORT=${FALSE}
            
            for (( port=${START}; port<=${END}; port++ ))
            do
                Paas::check-open-port ${port}
                if [ "${TUNNEL_LOCAL_PORT}" != "${FALSE}" ]; then
                    break
                fi
                if [ "${TUNNEL_LOCAL_PORT}" == "${FALSE}" ] && [ $port == $END ]; then
                    echo "No available port found. Close some tunnels with the close-tunnel command"
                    exit 1
                fi
            done

            return "${TRUE}"
            ;;
        'scheduler')
            START=5040
            END=5049
            TUNNEL_LOCAL_PORT=${FALSE}

            for (( port=${START}; port<=${END}; port++ ))
            do
                Paas::check-open-port ${port}
                if [ "${TUNNEL_LOCAL_PORT}" != "${FALSE}" ]; then
                    break
                fi
                if [ "${TUNNEL_LOCAL_PORT}" == "${FALSE}" ] && [ $port == $END ]; then
                    echo "No available port found. Close some tunnels with the close-tunnel command"
                    exit 1
                fi
            done

            return "${TRUE}"
            ;;
        'broker')
            START=5050
            END=5059
            TUNNEL_LOCAL_PORT=${FALSE}
            
            for (( port=${START}; port<=${END}; port++ ))
            do
                Paas::check-open-port ${port}
                if [ "${TUNNEL_LOCAL_PORT}" != "${FALSE}" ]; then
                    break
                fi
                if [ "${TUNNEL_LOCAL_PORT}" == "${FALSE}" ] && [ $port == $END ]; then
                    echo "No available port found. Close some tunnels with the close-tunnel command"
                    exit 1
                fi
            done

            return "${TRUE}"
            ;;
        *)
            Console::verbose "\nUnknown service ${INFO}${SERVICE}${WARN}."
            ;;
    esac

    return "${TRUE}"
}

# check if port is open
function Paas::check-open-port() {
    local port=$1

    if ( nc -z localhost ${port} &>/dev/null ); then
        echo "Port ${port} is Busy. Trying the next available port."
    else
        echo "Port ${port} is Free"
        TUNNEL_LOCAL_PORT=${port}
    fi

    return "${TRUE}"
}

# close an open port
function Paas::close-busy-port() {
    local port=$1

    if ( nc -z localhost ${port} &>/dev/null ); then
        echo "Closing port ${port}"
        lsof -i tcp:${port} | awk 'NR!=1 {print $2}' | xargs kill
    fi

    return "${TRUE}"
}

# check if a RDS READ Replica exists within the account
function Paas::check-read-replica-exists() {
    SPRYKER_DB_RO_REPLICA_DETAILS=$(aws rds describe-db-instances --region ${ENVIRONMENT_REGION} --db-instance-identifier "${ENVIRONMENT}"-ro-replica-0 --output text --no-cli-pager --query "DBInstances[*].Endpoint[].[Address,Port]" 2> /dev/null || true)
    if [ "${SPRYKER_DB_RO_REPLICA_DETAILS}" == "" ]; then
        SPRYKER_DB_RO_REPLICA_EXIST=${FALSE}
    fi

    return "${TRUE}"
}