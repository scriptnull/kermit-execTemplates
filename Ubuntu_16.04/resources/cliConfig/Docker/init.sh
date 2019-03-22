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
export REGISTRY_USERNAME=""
export REGISTRY_PASSWORD=""
export REGISTRY_EMAIL=""

help() {
  echo "
  Usage:
    $SCRIPT_NAME <resource_name> [scopes]
  "
}

check_params() {
  _log_msg "Checking params"

  REGISTRY_USERNAME="$( shipctl get_integration_resource_field "$RESOURCE_NAME" "username" )"
  REGISTRY_PASSWORD="$( shipctl get_integration_resource_field "$RESOURCE_NAME" "password" )"
  REGISTRY_EMAIL="$( shipctl get_integration_resource_field "$RESOURCE_NAME" "email" )"

  if _is_empty "$REGISTRY_USERNAME"; then
    _log_err "Missing 'username' value in $RESOURCE_NAME's integration."
    exit 1
  fi

  if _is_empty "$REGISTRY_PASSWORD"; then
    _log_err "Missing 'password' value in $RESOURCE_NAME's integration."
    exit 1
  fi

  if _is_empty "$REGISTRY_EMAIL"; then
    _log_err "Missing 'email' value in $RESOURCE_NAME's integration."
    exit 1
  fi

  _log_success "Successfully checked params"
}

init_scope_configure() {
  _log_msg "Initializing scope configure"

  if _is_docker_email_deprecated; then
    docker login -u "$REGISTRY_USERNAME" -p "$REGISTRY_PASSWORD"
  else
    docker login -u "$REGISTRY_USERNAME" -p "$REGISTRY_PASSWORD" -e "$REGISTRY_EMAIL"
  fi

  _log_success "Successfully initialized scope configure"
}

init() {
  RESOURCE_NAME=${ARGS[0]}

  _log_grp "Initializing Docker login for resource $RESOURCE_NAME"

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
