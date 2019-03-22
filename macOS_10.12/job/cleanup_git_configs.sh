cleanup_global_git_configs() {
  local global_git_configs=$(git config --global --list --name-only) || true
  if [ ! -z "$global_git_configs" ]; then
    for global_git_config in $global_git_configs
    do
      exec_cmd "echo 'Unsetting global git config $global_git_config'"
      exec_cmd "git config --global --unset-all $global_git_config"
    done
  else
    exec_cmd "echo 'No global git configs found'"
  fi
}

cleanup_git_configs() {
  cleanup_global_git_configs
  ret=$?
  [ "$ret" != 0 ] && return $ret;
  is_success=true
}

cleanup_git_configs
