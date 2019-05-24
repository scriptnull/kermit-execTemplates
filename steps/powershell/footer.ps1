Function before_exit() {
  if ($global:is_success) {
    Write-Output "__SH__SCRIPT_END_SUCCESS__"
  } else {
    Write-Output "__SH__SCRIPT_END_FAILURE__"
  }
}

Function main() {
  $global:is_success = $TRUE
  Try
  {
    onStart
    onExecute
    execute_command "onSuccess"
  }
  Catch
  {
    $global:is_success = $FALSE
    execute_command "onFailure"
  }
  Finally
  {
    execute_command "onComplete"
    output
    before_exit
  }
}

main
