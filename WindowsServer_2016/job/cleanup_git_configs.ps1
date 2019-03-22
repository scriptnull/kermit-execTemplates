function cleanup_global_git_configs() {
  $git_configs = git config --global --list --name-only
  foreach ($git_config in $git_configs) {
    exec_cmd "Write-Output 'Unsetting git config $git_config'"
    exec_cmd "git config --global --unset-all $git_config"
  }
}

cleanup_global_git_configs
