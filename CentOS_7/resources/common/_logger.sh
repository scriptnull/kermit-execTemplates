#!/bin/bash -e

# _log_grp logs the starting of a group
# args: string
_log_grp() {
  echo "$*"
}

# _log_msg logs a message under a group
# args: string
_log_msg() {
  echo "|___ $*"
}

# _log_err logs an error message under a group (in red color)
# args: string
_log_err() {
  local message="$*"
  local bold_red_text='\e[91m'
  local reset_text='\033[0m'

  echo -e "$bold_red_text|___ $message$reset_text"
}

# _log_success logs a success message under a group (in green color)
# args: string
_log_success() {
  local message="$*"
  local bold_green_text='\e[32m'
  local reset_text='\033[0m'

  echo -e "$bold_green_text|___ $message$reset_text"
}
