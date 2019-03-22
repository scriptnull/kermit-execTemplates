#!/bin/bash -e

readonly ROOT_DIR="$(dirname "$0")/../../.."
readonly COMMON_DIR="$ROOT_DIR/resources/common"
readonly HELPERS_PATH="$COMMON_DIR/_helpers.sh"
readonly LOGGER_PATH="$COMMON_DIR/_logger.sh"

# shellcheck source=macOS_10.12/resources/common/_helpers.sh
source "$HELPERS_PATH"
# shellcheck source=macOS_10.12/resources/common/_logger.sh
source "$LOGGER_PATH"

export RESOURCE_NAME=""
export RESOURCE_VERSION_PATH=""
export SCOPES=""
export AZUREKEYS_APPID=""
export AZUREKEYS_PASSWORD=""
export AZUREKEYS_TENANT=""
export AKS_GROUP_NAME=""
export AKS_CLUSTER_NAME=""

help() {
  echo "
  Usage:
    $SCRIPT_NAME <resource_name> [scopes]
  "
}

check_params() {
  _log_msg "Checking params"

  AZUREKEYS_APPID="$( shipctl get_integration_resource_field "$RESOURCE_NAME" "appId" )"
  AZUREKEYS_PASSWORD="$( shipctl get_integration_resource_field "$RESOURCE_NAME" "password" )"
  AZUREKEYS_TENANT="$( shipctl get_integration_resource_field "$RESOURCE_NAME" "tenant" )"
  RESOURCE_VERSION_PATH="$(shipctl get_resource_meta "$RESOURCE_NAME")/version.json"
  AKS_GROUP_NAME="$( shipctl get_json_value "$RESOURCE_VERSION_PATH" "version.propertyBag.groupName" )"
  AKS_CLUSTER_NAME="$( shipctl get_json_value "$RESOURCE_VERSION_PATH" "version.propertyBag.clusterName" )"

  if _is_empty "$AZUREKEYS_APPID"; then
    _log_err "Missing 'appId' value in $RESOURCE_NAME's integration."
    exit 1
  fi

  if _is_empty "$AZUREKEYS_PASSWORD"; then
    _log_err "Missing 'password' value in $RESOURCE_NAME's integration."
    exit 1
  fi

  if _is_empty "$AZUREKEYS_TENANT"; then
    _log_err "Missing 'tenant' value in pointer section of $RESOURCE_NAME's yml"
    exit 1
  fi

  _log_success "Successfully checked params"
}

init_scope_configure() {
  _log_msg "Initializing scope configure"

  az login --service-principal -u "$AZUREKEYS_APPID" --password "$AZUREKEYS_PASSWORD" --tenant "$AZUREKEYS_TENANT"

  _log_success "Successfully initialized scope configure"
}

init_scope_aks() {
  _log_msg "Initializing scope aks"

  az aks get-credentials -g "$AKS_GROUP_NAME" -n "$AKS_CLUSTER_NAME"

  _log_success "Successfully initialized scope aks"
}

init() {
  RESOURCE_NAME=${ARGS[0]}
  SCOPES=${ARGS[1]}

  _log_grp "Initializing azureKeys for resource $RESOURCE_NAME"

  check_params
  init_scope_configure
  if _csv_has_value "$SCOPES" "aks"; then
    init_scope_aks
  fi
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
