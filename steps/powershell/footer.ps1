Function before_exit() {
  if ($global:is_success) {
    Write-Output "__SH__SCRIPT_END_SUCCESS__"
  } else {
    Write-Output "__SH__SCRIPT_END_FAILURE__"
  }
  execute_command "onComplete"
}

Function main() {
  $global:is_success = $TRUE
  Try
  {
    onExecute
  }
  Catch
  {
    $global:is_success = $FALSE
  }
  Finally
  {
    before_exit
  }
}

main
