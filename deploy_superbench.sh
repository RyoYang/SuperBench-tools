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
deploy_superbench(){
    # install dependencies
    sudo apt-get update -y \
        && sudo apt-get -y install \
        python3.7-venv

    # link python3.7 as python3
    sudo rm -rf /usr/bin/python3 \
        && sudo  ln -s /usr/bin/python3.7 /usr/bin/python3

    # clone superbench
    rm -rf ./superbenchmark
    git init superbenchmark
    cd superbenchmark
    git remote add origin https://github.com/microsoft/superbenchmark.git
    git fetch origin
    git checkout -b main origin/main
    
    # create a new virtual environment
    rm -rf ./venv
    python3 -m venv --system-site-packages ./venv
    . ./venv/bin/activate

    python3 -m pip install --upgrade pip setuptools

    # install superbench
    python3 -m pip install .
    make postinstall

    # make postinstall
    sb deploy -f ../remote.ini --private-key ../private_key.txt
    sb run -c ../ib.yaml -f ../remote.ini

    # echo "##vso[task.setvariable variable=private_key_file]$private_key_file"    
}
hello_py(){
which python3
python3 <<-EOF
print("Hello python")
EOF
}

# hello_py
# To allow agents to gain access to the VMSS
deploy_superbench
hello_py
