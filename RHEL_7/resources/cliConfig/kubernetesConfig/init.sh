#!/bin/bash -e

readonly ROOT_DIR="$(dirname "$0")/../../.."
readonly COMMON_DIR="$ROOT_DIR/resources/common"
readonly HELPERS_PATH="$COMMON_DIR/_helpers.sh"
readonly LOGGER_PATH="$COMMON_DIR/_logger.sh"

# shellcheck source=Ubuntu_16.04/resources/common/_helpers.sh
source "$HELPERS_PATH"
# shellcheck source=Ubuntu_16.04/resources/common/_logger.sh
source "$LOGGER_PATH"

export KUBERNETES_KUBECONFIGFILE=""
export KUBERNETES_INT=""

help() {
  echo "
  Usage:
    $SCRIPT_NAME <resource_name> [scopes]
  "
}

check_params() {
  _log_msg "Checking params"

  KUBERNETES_INT="$(shipctl get_integration_resource "$RESOURCE_NAME")"
  KUBERNETES_KUBECONFIGFILE="$( echo "$KUBERNETES_INT" | jq -r '.kubeConfigContent' )"

  if _is_empty "$KUBERNETES_KUBECONFIGFILE"; then
    _log_err "Missing 'kubeConfigFile' value in $RESOURCE_NAME's integration."
    exit 1
  fi

  _log_success "Successfully checked params"
}

init_scope_configure() {
  _log_msg "Initializing scope configure"

  mkdir ~/.kube
  echo "$KUBERNETES_KUBECONFIGFILE" > /root/.kube/config

  _log_success "Successfully initialized scope configure"
}

init() {
  RESOURCE_NAME=${ARGS[0]}

  _log_grp "Initializing kubernetesConfig for resource $RESOURCE_NAME"

  check_params
  init_scope_configure
}

main() {
  if [[ "${#ARGS[@]}" -gt 0 ]]; then
    case "${ARGS[0]}" in
      --help)
        help
        exit 0
        ;;
      *)
        init
        ;;
    esac
  else
    help
    exit 1
  fi
}

main
