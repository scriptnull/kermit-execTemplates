#!/bin/bash -e

readonly ROOT_DIR="$(dirname "$0")/../../.."
readonly COMMON_DIR="$ROOT_DIR/resources/common"
readonly HELPERS_PATH="$COMMON_DIR/_helpers.sh"
readonly LOGGER_PATH="$COMMON_DIR/_logger.sh"

# shellcheck source=Ubuntu_14.04/resources/common/_helpers.sh
source "$HELPERS_PATH"
# shellcheck source=Ubuntu_14.04/resources/common/_logger.sh
source "$LOGGER_PATH"

export RESOURCE_NAME=""
export JFROG_USERNAME=""
export JFROG_PASSWORD=""
export JFROG_URL=""

help() {
  echo "
  Usage:
    $SCRIPT_NAME <resource_name> [scopes]
  "
}

check_params() {
  _log_msg "Checking params"

  JFROG_USERNAME="$( shipctl get_integration_resource_field "$RESOURCE_NAME" "userName" )"
  JFROG_PASSWORD="$( shipctl get_integration_resource_field "$RESOURCE_NAME" "password" )"
  JFROG_URL="$( shipctl get_integration_resource_field "$RESOURCE_NAME" "url" )"

  if _is_empty "$JFROG_USERNAME"; then
    _log_err "Missing 'userName' value in $RESOURCE_NAME's integration."
    exit 1
  fi

  if _is_empty "$JFROG_PASSWORD"; then
    _log_err "Missing 'password' value in $RESOURCE_NAME's integration."
    exit 1
  fi

  if _is_empty "$JFROG_URL"; then
    _log_err "Missing 'url' value in pointer section of $RESOURCE_NAME's yml"
    exit 1
  fi

  _log_success "Successfully checked params"
}

init_scope_configure() {
  _log_msg "Initializing scope configure"

  if _is_jfrog_version_new; then
    jfrog rt config default-server --url "$JFROG_URL" \
    --password "$JFROG_PASSWORD" --user "$JFROG_USERNAME" \
    --interactive=false
    jfrog rt use default-server
  else
    jfrog rt config --url "$JFROG_URL" --password \
    "$JFROG_PASSWORD" --user "$JFROG_USERNAME"
  fi;

  _log_success "Successfully initialized scope configure"
}

init() {
  RESOURCE_NAME=${ARGS[0]}

  _log_grp "Initializing artifactory for resource $RESOURCE_NAME"
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
