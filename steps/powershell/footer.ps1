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
    if (Get-Command "onStart" -errorAction SilentlyContinue) {
      onStart
    }
    if (Get-Command "onExecute" -errorAction SilentlyContinue) {
      onExecute
    }
    if (Get-Command "onSuccess" -errorAction SilentlyContinue) {
      execute_command "onSuccess"
    }
  }
  Catch
  {
    $global:is_success = $FALSE
    if (Get-Command "onFailure" -errorAction SilentlyContinue) {
      execute_command "onFailure"
    }
  }
  Finally
  {
    if (Get-Command "onComplete" -errorAction SilentlyContinue) {
      execute_command "onComplete"
    }
    before_exit
  }
}

main
