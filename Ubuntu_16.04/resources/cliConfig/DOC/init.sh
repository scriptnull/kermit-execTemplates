#!/bin/bash -e

readonly ROOT_DIR="$(dirname "$0")/../../.."
readonly COMMON_DIR="$ROOT_DIR/resources/common"
readonly HELPERS_PATH="$COMMON_DIR/_helpers.sh"
readonly LOGGER_PATH="$COMMON_DIR/_logger.sh"

# shellcheck source=Ubuntu_16.04/resources/common/_helpers.sh
source "$HELPERS_PATH"
# shellcheck source=Ubuntu_16.04/resources/common/_logger.sh
source "$LOGGER_PATH"

export RESOURCE_NAME=""
export DO_API_TOKEN=""

help() {
  echo "
  Usage:
    $SCRIPT_NAME <resource_name> [scopes]
  "
}

check_params() {
  _log_msg "Checking params"

  DO_API_TOKEN="$( shipctl get_integration_resource_field "$RESOURCE_NAME" "apiToken" )"

  if _is_empty "$DO_API_TOKEN"; then
    _log_err "Missing 'apiToken' value in $RESOURCE_NAME's integration."
    exit 1
  fi

  _log_success "Successfully checked params"
}

init_scope_configure() {
  _log_msg "Initializing scope configure"

  echo "export DIGITALOCEAN_ACCESS_TOKEN=$DO_API_TOKEN" >> "$SHIPPABLE_INTEGRATION_ENVS_PATH"

  _log_success "Successfully initialized scope configure"
}

init() {
  RESOURCE_NAME=${ARGS[0]}

  _log_grp "Configuring Digital Ocean credentials for resource $RESOURCE_NAME"

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
