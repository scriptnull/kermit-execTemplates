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
export SCOPES=""
export GCR_JSON_KEY=""
export RESOURCE_PATH=""

help() {
  echo "
  Usage:
    $SCRIPT_NAME <resource_name> [scopes]
  "
}

check_params() {
  _log_msg "Checking params"

  GCR_JSON_KEY="$( shipctl get_integration_resource_field "$RESOURCE_NAME" "JSON_key" )"
  RESOURCE_PATH="$(shipctl get_resource_meta "$RESOURCE_NAME")"

  if _is_empty "$GCR_JSON_KEY"; then
    _log_err "Missing 'JSON_key' value in $RESOURCE_NAME's integration."
    exit 1
  fi

  _log_success "Successfully checked params"
}

init_scope_configure() {
  _log_msg "Initializing scope configure"

  pushd "$RESOURCE_PATH"
  touch key.json
  echo "$GCR_JSON_KEY" > key.json
  gcloud -q auth activate-service-account --key-file "key.json"
  gcloud docker -a
  popd

  _log_success "Successfully initialized scope configure"
}

init() {
  RESOURCE_NAME=${ARGS[0]}
  SCOPES=${ARGS[1]}

  _log_grp "Initializing Google Container Registry for resource $RESOURCE_NAME"

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
