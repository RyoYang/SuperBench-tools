#!/bin/bash
set -e
set -x

echo "working directory:"
pwd

USER_NAME=$1
HOST_LIST=$2
MASTER_NODE=$3
SSH_PRIVATE_KEY_PATH=$4
RUN_IB_TRAFFIC=$5
RUN_NCCL_TEST=$6
NCCL_PATTERN=$7
BATCH_SIZE=$8
IBNETDISCOVER_PATH=$9

DIR=/home/${USER_NAME}/ib-validation
CONFIG_DIR=$DIR/superbenchmark/superbench/config/azure_ndv4_distributed.yaml
RESULT_DIR=$DIR/superbench-results
LOG_NAME=`date "+%Y-%m-%d-%H-%M-%S"`
RESULT_LOG_DIR=$RESULT_DIR/superbench-results/$LOG_NAME

DIAGNOSIS_SUMMARY_FILE=$RESULT_DIR/superbench-results/$LOG_NAME/diagnosis_summary.json

rm -rf $DIR

mkdir -p $DIR
mkdir -p $RESULT_DIR
mkdir -p $RESULT_LOG_DIR

# Install dependencies
sudo apt-get update -y \
    && sudo apt-get -y install \
    python3.7-venv

# Link python3.7 as python3
sudo rm -rf /usr/bin/python3 \
    && sudo  ln -s /usr/bin/python3.7 /usr/bin/python3

# Clone superbench
cd $DIR

rm -rf ./superbenchmark
git init superbenchmark
cd superbenchmark
git remote add origin https://github.com/microsoft/superbenchmark.git
git fetch origin
git checkout -b yangwang1/arm-temp origin/yangwang1/arm-temp

# Create a new virtual environment
rm -rf ./venv
python3 -m venv --system-site-packages ./venv
. ./venv/bin/activate

python3 -m pip install --upgrade pip setuptools

# Install superbench
python3 -m pip install .
make postinstall

# Create inventory file
splited_host_list=$(echo "$HOST_LIST" | tr ' ' '\n')
cat << EOF > $DIR/remote.ini
[all]
$splited_host_list

[all:vars]
ansible_ssh_private_key_file=$SSH_PRIVATE_KEY_PATH
ansible_user=$USER_NAME
EOF

# Update config file
if [[ $RUN_IB_TRAFFIC == "true" ]]; then
    sed -i "s/# - ib-traffic:pair_ise/- ib-traffic:pair_wise/g" $CONFIG_DIR
fi

if [[ $RUN_NCCL_TEST == "true" ]]; then
    sed -i "s/# - nccl-bw:all-nodes/- nccl-bw:$NCCL_PATTERN/g" $CONFIG_DIR
    sed -i "s/<<: *nccl_all_nodes_pattern/<<: *nccl_${NCCL_PATTERN}_pattern/g" $CONFIG_DIR
fi

if [[ "$NCCL_PATTERN" == "k_batch" ]]; then
    sed -i "s/batch: 3/batch: $BATCH_SIZE/g" $CONFIG_DIR
fi

if [[ "$NCCL_PATTERN" == "topo_aware" ]]; then
    sed -i "s/ibnetdiscover:/ibnetdiscover: $IBNETDISCOVER_PATH/g" $CONFIG_DIR
fi

# Deploy & Run superbench
sb deploy -f $DIR/remote.ini --private-key $SSH_PRIVATE_KEY_PATH
sb run -c $DIR/ib-validation.yaml -f $DIR/remote.ini --output-dir $RESULT_DIR
# sb result diagnosis -d $RESULT_LOG_DIR/results-summary.jsonl -b $DIR/sbib-ndv4.json -r $DIR/diagnosis-rules.yaml --output-dir $RESULT_LOG_DIR --output-all --output-file-format json


python3 - << EOF
import subprocess
import json

def execute_cmd(cmd: str):
    print(f"execute {cmd}")
    output = subprocess.check_output(cmd, shell=True)
    print(f"output is: {output}")
    return output

def generate_ansible_host(ipaddress, username, host_path):
    ips = json.loads(ipaddress)
    lines = []
    lines.append('[all]')
    for ip in ips:
        lines.append(ip)
    lines.append('')

    lines.append('[master]')
    lines.append(ips[0])
    lines.append('')

    lines.append('[all:vars]')
    lines.append('ansible_user=' + username)
    with open(host_path, 'w') as f:
        f.writelines([line + '\n' for line in lines])


if __name__ == "__main__":
    print("start to run host_generator.py")
    hosts = ''
    if (len(hosts) == 0):
        print("hosts is empty, will deploy to all instances in vmss")
        output = execute_cmd(f'az vmss nic list -g $RESOURCE_GROUP --vmss-name $VMSS_NAME --query "[].ipConfigurations[].privateIpAddress"')
    else:
        output = json.dumps(hosts.split(','))

    generate_ansible_host(output, $username, $path)
    print("exit host_generator.py")
EOF

echo "Back to bash"
