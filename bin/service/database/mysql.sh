#!/bin/bash


function Database::haveTables() {
    if ! Service::isServiceExist 'database'; then
        return;
    fi

    tableCount=$(
        Compose::exec <<'EOF'
        export VERBOSE=0
        export MYSQL_PWD="${SPRYKER_DB_ROOT_PASSWORD}"
        databases="$(echo ${SPRYKER_PAAS_SERVICES} | jq  '.databases')";
        if [ -z "${databases}" ] || [ "${databases}" == "[]" ]; then
            mysql \
                -h "${SPRYKER_DB_HOST}" \
                -u "${SPRYKER_DB_ROOT_USERNAME}" \
                -e "SELECT TABLE_NAME FROM information_schema.tables WHERE table_schema = \"${SPRYKER_DB_DATABASE}\"" \
                | wc -l \
                |  sed "s/^ *//" \
                | tr -d " \n\r" \
                || echo 0
        else
            echo ${databases} | jq -c '.[]' | while read line; do
                SPRYKER_DB_HOST=$(echo $line | jq -r .host);
                SPRYKER_DB_DATABASE=$(echo $line | jq -r .database);
                tablesCountPerDb=$(mysql \
                    -h "${SPRYKER_DB_HOST}" \
                    -u "${SPRYKER_DB_ROOT_USERNAME}" \
                    -e "SELECT TABLE_NAME FROM information_schema.tables WHERE table_schema = \"${SPRYKER_DB_DATABASE}\"" \
                    | wc -l \
                    |  sed "s/^ *//" \
                    | tr -d " \n\r" \
                    || echo 0)

                if [ "$tablesCountPerDb" == 0 ]; then
                    echo 0;
                    break
                fi

            done

            echo 1;
        fi
EOF
    )

    ( [ ! -z "${tableCount}" ] &&  [ "${tableCount}" -gt 0 ]) && return "${TRUE}" || return "${FALSE}"
}

function Database::init() {
      if ! Service::isServiceExist database; then
          return;
      fi

      Compose::exec <<'EOF'
        export MYSQL_PWD="${SPRYKER_DB_ROOT_PASSWORD}";
        databases="$(echo ${SPRYKER_PAAS_SERVICES} | jq  '.databases')";

        if [ -z "${databases}" ] || [ "${databases}" == "[]" ]; then
            mysql \
                -h "${SPRYKER_DB_HOST}" \
                -u root \
                -e "CREATE DATABASE IF NOT EXISTS \`${SPRYKER_DB_DATABASE}\` CHARACTER SET \"${SPRYKER_DB_CHARACTER_SET}\" COLLATE \"${SPRYKER_DB_COLLATE}\"; GRANT ALL PRIVILEGES ON \`${SPRYKER_DB_DATABASE}\`.* TO \"${SPRYKER_DB_USERNAME}\"@\"%\" IDENTIFIED BY \"${SPRYKER_DB_PASSWORD}\" WITH GRANT OPTION;"
        else
            echo ${databases} | jq -c '.[]' | while read line; do
              SPRYKER_DB_HOST=$(echo $line | jq -r .host);
              SPRYKER_DB_USERNAME=$(echo $line | jq -r .username);
              SPRYKER_DB_PASSWORD=$(echo $line | jq -r .password);
              SPRYKER_DB_DATABASE=$(echo $line | jq -r .database);
              SPRYKER_DB_CHARACTER_SET=$(echo $line | jq -r .characterSet);
              SPRYKER_DB_COLLATE=$(echo $line | jq -r .collate);
              export MYSQL_PWD="${SPRYKER_DB_ROOT_PASSWORD}";
              mysql \
                -h "${SPRYKER_DB_HOST}" \
                -u root \
                -e "CREATE DATABASE IF NOT EXISTS \`${SPRYKER_DB_DATABASE}\` CHARACTER SET \"${SPRYKER_DB_CHARACTER_SET}\" COLLATE \"${SPRYKER_DB_COLLATE}\"; GRANT ALL PRIVILEGES ON \`${SPRYKER_DB_DATABASE}\`.* TO \"${SPRYKER_DB_USERNAME}\"@\"%\" IDENTIFIED BY \"${SPRYKER_DB_PASSWORD}\" WITH GRANT OPTION;"
            done
        fi
EOF
}
