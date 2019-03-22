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
export SCOPES=""
export GKE_JSON_KEY=""
export RESOURCE_PATH=""
export GKE_PROJECT_ID=""
export RESOURCE_VERSION_PATH=""
export GKE_REGION=""
export GKE_CLUSTER_NAME=""

help() {
  echo "
  Usage:
    $SCRIPT_NAME <resource_name> [scopes]
  "
}

check_params() {
  _log_msg "Checking params"

  GKE_JSON_KEY="$( shipctl get_integration_resource_field "$RESOURCE_NAME" "JSON_key" )"
  if _is_empty "$GKE_JSON_KEY"; then
    _log_err "Missing 'JSON_key' value in $RESOURCE_NAME's integration."
    exit 1
  fi
  GKE_PROJECT_ID="$( echo "$GKE_JSON_KEY" | jq -r '.project_id' )"
  RESOURCE_PATH="$(shipctl get_resource_meta "$RESOURCE_NAME")"
  RESOURCE_VERSION_PATH="$(shipctl get_resource_meta "$RESOURCE_NAME")/version.json"
  GKE_REGION="$( shipctl get_json_value "$RESOURCE_VERSION_PATH" "version.propertyBag.region" )"
  GKE_CLUSTER_NAME="$( shipctl get_json_value "$RESOURCE_VERSION_PATH" "version.propertyBag.clusterName" )"

  _log_success "Successfully checked params"
}

init_scope_configure() {
  _log_msg "Initializing scope configure"

  pushd "$RESOURCE_PATH"
  touch key.json
  echo "$GKE_JSON_KEY" > key.json
  if ! _is_empty "$GKE_PROJECT_ID"; then
    gcloud -q auth activate-service-account --key-file "key.json" --project "$GKE_PROJECT_ID"
  else
    gcloud -q auth activate-service-account --key-file "key.json"
  fi
  popd

  if ! _is_empty "$GKE_REGION"; then
    gcloud config set compute/zone "$GKE_REGION"
  fi

  if ! _is_empty "$GKE_CLUSTER_NAME"; then
    gcloud config set container/use_client_certificate True
    gcloud config set container/cluster "$GKE_CLUSTER_NAME"
    gcloud container clusters get-credentials "$GKE_CLUSTER_NAME"
  fi

  _log_success "Successfully initialized scope configure"
}

init() {
  RESOURCE_NAME=${ARGS[0]}
  SCOPES=${ARGS[1]}

  _log_grp "Initializing Google Kubernetes Engine for resource $RESOURCE_NAME"

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
