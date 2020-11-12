#!/bin/bash

set -e

INSTANCE_IP=""
INSTANCE2_IP=""
ROOT_TOKEN=""

SCRIPT_NAME="e2e.sh"

function log {
  local -r level="$1"
  local -r message="$2"
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [$SCRIPT_NAME] ${message}"
}

function log_info {
  local -r message="$1"
  log "INFO" "$message"
}

function log_warn {
  local -r message="$1"
  log "WARN" "$message"
}

function log_error {
  local -r message="$1"
  log "ERROR" "$message"
}

function assert_not_empty {
  local -r arg_name="$1"
  local -r arg_value="$2"

  if [[ -z "$arg_value" ]]; then
    log_error "The value for '$arg_name' cannot be empty"
    print_usage
    exit 1
  fi
}

# A retry function that attempts to run a command a number of times and returns the output
function retry {
  local -r cmd="$1"
  local -r description="$2"

  for i in $(seq 1 15); do
    log_info "$description"

    # The boolean operations with the exit status are there to temporarily circumvent the "set -e" at the
    # beginning of this script which exits the script immediatelly for error status while not losing the exit status code
    output=$(eval "$cmd") && exit_status=0 || exit_status=$?
    log_info "$output"
    if [[ $exit_status -eq 0 ]]; then
      echo "$output"
      return
    fi
    log_warn "$description failed. Will sleep for 10 seconds and try again."
    sleep 10
  done;

  log_error "$description failed after 15 attempts."
  exit $exit_status
}

function get_instance_ip() {
  local -r tfitem="$1"

  if [[ -z "$tfitem" ]]; then
    log_error "Need to provide a TF output value.."
    exit 1
  fi

  tf_out=$(terraform output ${tfitem})
  if [[ $tf_out == "" ]]; then
    log_error "Can't find instance ip from TF, quitting..."
    exit 1
  fi

  log_info "Found ${tfitem} ${tf_out}"

  if [[ "$tfitem" == "instance_ip" ]]; then
    INSTANCE_IP=$tf_out
  fi

  if [[ "$tfitem" == "instance2_ip" ]]; then
    INSTANCE2_IP=$tf_out
  fi
}

function wait_for_instance() {
 local -r ip="$1"

 if [[ -z "$ip" ]]; then
   log_error "Need to provide an IP to wait for instance"
   exit 1
 fi

  retry "ssh -o 'StrictHostKeyChecking=no' centos@${ip} sudo cloud-init status --wait" "Waiting for cloud-init..."
}

function start_vault() {
  local -r ip="$1"
  local init="$2"
  local seal="$3"

  if [[ -z "$ip" ]]; then
    log_error "Need to provide IP to start_vault"
    exit 1
  fi

  if [[ -z "$init" ]]; then
    log_info "No init target state specified, checking for false"
    init="false"
  fi

  if [[ -z "$seal" ]]; then
    log_info "No seal target state specified, checking for true"
    seal="true"
  fi


  log_info "Starting Vault on ${ip}"
  ssh centos@${ip} sudo systemctl start vault
  log_info "Sleeping for 10, waiting for Vault to start..."
  sleep 10

  status=$(ssh centos@"$ip" VAULT_ADDR=http://127.0.0.1:8200 vault status -format=json | jq -r '.')

  actual_init=$(echo $status | jq -r '.initialized')
  actual_seal=$(echo $status | jq -r '.sealed')

  if [[ "$init" != "$actual_init" ]]; then
    log_error "Init status invalid: ${init} did not equal ${actual_init}"
    exit 1
  fi

  if [[ "$seal" != "$actual_seal" ]]; then
    log_error "Seal status: ${seal} did not equal ${actual_seal}"
    exit 1
  fi

  log_info "Vault appears to have started.."

}

function stop_vault() {
  local -r ip="$1"

  if [[ -z "$ip" ]]; then
    log_error "Need to provide IP to stop_vault"
    exit 1
  fi

  log_info "Stopping vault service on ${ip}"

  ssh centos@${ip} sudo systemctl stop vault
}

function vault_init() {
  local -r ip="$1"

  if [[ -z "$ip" ]]; then
    log_error "Need to provide IP to init vault"
    exit 1
  fi

  log_info "Initializing Vault on ${ip}"

  init=$(ssh centos@${ip} VAULT_ADDR=http://127.0.0.1:8200 vault operator init -format=json | jq -r '.')
  ROOT_TOKEN=$(echo $init | jq -r '.root_token')

  log_info "Got ROOT Token: ${ROOT_TOKEN}"
}

function vault_list_peers() {
  local -r ip="$1"

  if [[ -z "$ip" ]]; then
    log_error "Need to provide IP to check peers"
    exit 1
  fi

  log_info "Fetching raft peer list"

  peers=$(ssh centos@${ip} VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=${ROOT_TOKEN} vault operator raft list-peers -format=json | jq -r '.')
  peer_count=$(echo $peers | jq -r '.data.config.servers | length')

  if [[ "$peer_count" != "2" ]]; then
    log_error "Peer count doesn't equal 2, instead it equals ${peer_count}"
    exit 1
  fi

  log_info "Looks like we have two peers, which is correct!!"
}

function push_file() {
  local -r ip="$1"
  local -r file="$2"

  if [[ -z "$ip" ]]; then
    log_error "Need to provide IP to push file to"
    exit 1
  fi

  if [[ -z "$file" ]]; then
    log_error "Need to provide path to file"
    exit 1
  fi

  log_info "Pushing ${file} to ${ip}:selinux.rpm"

  scp ${file} centos@${ip}:selinux.rpm
}

function install_rpm() {
  local -r ip="$1"

  if [[ -z "$ip" ]]; then
    log_error "Need to provide IP to install the uploaded RPM"
    exit 1
  fi

  log_info "Installing the ~/selinux.rpm on ${ip}"

  ssh centos@${ip} sudo yum install -y ./selinux.rpm
}

function update_selinux_outbound() {
  local -r ip="$1"
  local -r state="$2"

  if [[ -z "$ip" ]]; then
    log_error "Need to provide IP to update selinux bools"
    exit 1
  fi

  if [[ -z "$state" ]]; then
    log_error "Need to provide target state of on or off"
    exit 1
  fi

  log_info "Updating selinux policies to allow outbound DNS and HTTP"

  ssh centos@${ip} sudo setsebool vault_outbound_udp_dns ${state}
  ssh centos@${ip} sudo setsebool vault_outbound_http ${state}
}

function print_usage() {
  echo
  echo "Usage: ./e2e.sh [OPTIONS]"
  echo
  echo "Options:"
  echo
  echo -e "  --rpm-file\t\tThe full path to the SELinux RPM file for testing. This is required"
  echo -e "  --help\t\tPrint help"
}

function e2e {
  local rpm_file=""

  while [[ $# > 0 ]]; do
    local key="$1"

    case "$key" in
      --rpm-file)
        rpm_file="$2"
        shift
        ;;
      --help)
        print_usage
        exit
        ;;
      *)
        log_error "Unrecognized argument: $key"
        print_usage
        exit 1
        ;;
    esac

    shift
  done

  assert_not_empty "--rpm-file" "$rpm_file"

  log_info "====================== Starting cluster"

  get_instance_ip "instance_ip"
  wait_for_instance $INSTANCE_IP

  start_vault $INSTANCE_IP
  vault_init $INSTANCE_IP

  get_instance_ip "instance2_ip"
  wait_for_instance $INSTANCE2_IP

  start_vault $INSTANCE2_IP "true" "false"

  vault_list_peers $INSTANCE_IP

  log_info "====================== Stopping cluster"

  stop_vault $INSTANCE2_IP
  stop_vault $INSTANCE_IP

  log_info "====================== Pushing RPMs to cluster"

  push_file $INSTANCE_IP $rpm_file
  install_rpm $INSTANCE_IP
  update_selinux_outbound $INSTANCE_IP "on"

  push_file $INSTANCE2_IP $rpm_file
  install_rpm $INSTANCE2_IP
  update_selinux_outbound $INSTANCE2_IP "on"

  log_info "====================== Restarting vault cluster"

  start_vault $INSTANCE_IP "true" "false"
  start_vault $INSTANCE2_IP "true" "false"

  vault_list_peers $INSTANCE_IP

  log_info "====================== End to End Testing Completed Successfully!"
}

e2e "$@"
