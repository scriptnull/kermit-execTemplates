#!/bin/bash -e

readonly IFS=$' \n\t'
readonly SCRIPT_NAME="$( basename "$0" )"
readonly ARGS=("$@")

# _is_empty checks if given value is "" or "null"
# args: string
_is_empty() {
  [[ -z "$1" ]] || [[ "$1" == "null" ]]
}

# csv_has_value checks if a `value` is present in a `csv` (comma separated value) string
# args: csv(string), value(string)
_csv_has_value() {
  local csv=$1
  local value=$2
  [[ $csv =~ (^|,)$value(,|$) ]]
}

# is_docker_email_deprecated checks if email argument is deprected in docker command for current docker version
# args: none
_is_docker_email_deprecated() {
  local docker_version=""
  local docker_major_version=""
  local email_deprecated_version=17

  docker_version="$( docker version --format \{\{.Server.Version\}\} )"
  docker_major_version=$(echo "$docker_version" | awk -F '.' '{print $1}')

  [[ "$docker_major_version" -ge "$email_deprecated_version" ]]
}

# _is_jfrog_version_new checks if jfrog version is new or old
_is_jfrog_version_new() {
  local jfrog_version=""
  local jfrog_major_version=""
  local jfrog_minor_version=""

  jfrog_version=$(jfrog --version | awk '{print $3}' )
  jfrog_major_version=$(echo "$jfrog_version" | awk -F '.' '{print $1}' )
  jfrog_minor_version=$(echo "$jfrog_version" | awk -F '.' '{print $2}' )

  [[ "$jfrog_major_version" -gt "1" ]] || ( [[ "$jfrog_major_version" -eq "1" ]] &&
    [[ "$jfrog_minor_version" -gt "9" ]] )
}
