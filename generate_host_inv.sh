#!/bin/bash

####
# @Brief        : Function to report errors
# @Param        : (1) #Error code
#                 (2) #Error message
# @RetVal       : null
####
report_error(){
    error_code=$1
    error_message=$2

    cat <<EOF > error_info.json
    {
        "Code": "${error_code}",
        "Message": "${error_message}",
        "Timestamp": "$(date -u +%a,\ %d\ %b\ %Y\ %H:%M:%S\ GMT)"
    }
EOF
    
    echo "##[error]${error_message}"
    echo "Pushing error information onto log analytics container"
    bash tologanalytics.sh "${LOG_ANALYTICS_CONTAINER}" "error_info.json"
    exit ${error_code}
}

####
# @Brief        : Function to run an az command
# @Param        : command string
# @RetVal       : output of command
####
run_command(){
    command_string=$1
    echo "##[command]${command_string}"
    output=$(eval ${command_string} 2>&1) || { report_error "$?" "$output"; }
    echo "$output"
}

####
# @Brief        : Generate host.ini for Agent
# @Param        : null
# @RetVal       : null~
####
generate_host_inv(){
    host_inv="host.ini"
    if [ ! -f "${WORKING_FOLDER}/${host_inv}" ]
    then
        echo "##[section]Genrating Host Inventory"
        echo '[all]' > ${WORKING_FOLDER}/${host_inv}
        command_string="echo ${HOST_LIST} | tr ' ' '\n' >> ${WORKING_FOLDER}/${host_inv}"
        run_command "${command_string}"

        # Change the permissions to read-only
        echo "Setting appropriate permissions to the host.ini"
        chmod 400 ${WORKING_FOLDER}/${host_inv}
    else
        echo "##[warning]Host Inventory already exists!"
    fi

    echo "##vso[task.setvariable variable=host_inv]$host_inv"    
}

# To allow agents to gain all host names from host list
generate_host_inv
