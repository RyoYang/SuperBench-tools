#!/bin/bash
set -e
set -x

USER_NAME=$1
HOST_LIST=$2
MASTER_NODE=$3
SSH_PRIVATE_KEY_PATH=$4

hostname=`hostname`
if [[ "$hostname" != $MASTER_NODE ]]
then
    echo "not master node, skip deployment"
    exit 0
fi

DIR=/home/${USER_NAME}/ib-validation

rm -rf $DIR
mkdir -p $DIR

apt-waitlock() {
  while fuser /var/lib/dpkg/lock >/dev/null 2>&1 ; do sleep 0.5; done
}

deploy_superbench(){
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
    git checkout -b main origin/main
    
    # Create a new virtual environment
    rm -rf ./venv
    python3 -m venv --system-site-packages ./venv
    . ./venv/bin/activate

    python3 -m pip install --upgrade pip setuptools

    # Install superbench
    python3 -m pip install .
    make postinstall

    # Deploy & Run superbench
    sb deploy -f $DIR/remote.ini --private-key $SSH_PRIVATE_KEY_PATH
    sb run -c $DIR/ib-validation.yaml -f $DIR/remote.ini
}

create_remote_ini(){
    formatted_string=$(echo "$HOST_LIST" | tr ' ' '\n')
    cat << EOF > $DIR/remote.ini
[all]
$formatted_string

[all:vars]
ansible_ssh_private_key_file=$SSH_PRIVATE_KEY_PATH
ansible_user=$USER_NAME
EOF
}

create_sb_config(){
    cat << EOF > $DIR/ib-validation.yaml
version: v0.6
superbench:
  enable:
  - ib-traffic:pair-wise
  - nccl-bw:pair-wise
  # - model-benchmarks:stress
  monitor:
    enable: true
    sample_duration: 1
    sample_interval: 10
  var:
    nccl_env: &nccl_env
      NCCL_IB_PCI_RELAXED_ORDERING: '1'
      NCCL_NET_GDR_LEVEL: '5'
      NCCL_TOPO_FILE: /opt/microsoft/ndv4-topo.xml
      NCCL_DEBUG: WARN
    nccl_allreduce_config: &nccl_allreduce_config
      timeout: 1200
      modes:
      - name: mpi
        proc_num: 8
        node_num: all
        pattern:
          type: pair-wise
          mpi_pattern: true
        env:
          <<: *nccl_env
      parameters:
        # run_count: 5
        minbytes: 1K
        maxbytes: 16G
        stepfactor: 2
        check: 1
        warmup_iters: 20
        iters: 100
    torch_dist_config: &torch_dist_config
      timeout: 3600
      modes:
      - name: torch.distributed
        proc_num: 8
        node_num: all
        env:
          <<: *nccl_env
      frameworks: [pytorch]
      models: [gpt2-large]
      parameters:
        # run_count: 5
        duration: 1800
        num_warmup: 64
        num_steps: -100
        sample_count: 8192
        batch_size: 8
        seq_len: 224
        precision: [float32]
        model_action: [train]
        pin_memory: yes
  benchmarks:
    ib-traffic:pair-wise:
      modes:
      - name: mpi
        proc_num: 8
        node_num: all
        mca:
          routed: direct
      parameters:
        msg_size: 8388608
        bidirectional: yes
        ib_dev: mlx5_ib\$LOCAL_RANK
        gpu_dev: \$LOCAL_RANK
        numa_dev: \$((LOCAL_RANK/2))
    nccl-bw:pair-wise:
      <<: *nccl_allreduce_config
    # model benchmark - training
    model-benchmarks:stress:
      <<: *torch_dist_config
EOF
}

create_remote_ini
create_sb_config
deploy_superbench
