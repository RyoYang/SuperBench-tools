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
# @Brief        : Download credential to allow agent access to VMs
# @Param        : null
# @RetVal       : null
####
download_files(){
    for required_file in ${REQUIRED_FILES[@]}; do    
        if [ ! -f "${required_file}" ]
        then
            echo "##[section]Downloading ${required_file} from storage account"
            command_string="az storage blob download \
                --account-name ${STORAGE_ACC_NAME} \
                --container-name ${STORAGE_CON_NAME} \
                --account-key ${STORAGE_ACC_KEY} \
                --name ${required_file} \
                --file ${WORKING_FOLDER}/${required_file}"
            run_command "${command_string}"

            # Change the permissions to read-only
            echo "Setting appropriate permissions to the files"
            chmod 400 ${WORKING_FOLDER}/${required_file}
        else
            echo "##[warning]${required_file} already exists!"
        fi
    done

    # echo "##vso[task.setvariable variable=private_key_file]$private_key_file"    
}

# To allow agents to gain access to the VMSS
download_files
