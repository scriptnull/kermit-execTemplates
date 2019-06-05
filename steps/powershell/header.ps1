$open_group_list = New-Object System.Collections.Stack

class Group {
  [string]$name
  [string]$uuid
  [string]$parent_uuid
  [bool]$shown
  [int]$status
}

Function stop_group() {
  if ($open_group_list.Count -lt 1) {
    return
  }

  # stop the most recently started group
  $group = $open_group_list.Peek()

  $date_time = (Get-Date).ToUniversalTime()
  $group_end_timestamp = [System.Math]::Truncate((Get-Date -Date $date_time -UFormat %s))

  Write-Output "__SH__GROUP__END__|{`"type`":`"grp`",`"sequenceNumber`":`"$group_end_timestamp`",`"id`":`"$($group.uuid)`",`"is_shown`":`"$($group.shown)`",`"exitcode`":`"$($group.status)`"}|$($group.name)"

  $open_group_list.Pop() | Out-Null
}

Function start_group([string]$group_name, [bool]$is_shown = $TRUE) {
  if (-not ($group_name)) {
    Write-Error "Error: missing group name as first argument."
  }

  # if there are already 2 groups open, force close one before starting a new one
  # this prevents repeated nesting
  if ($open_group_list.Count -gt 1) {
    stop_group
  }

  $group_uuid = [guid]::NewGuid().Guid

  # if at least one group is already open, use it as a parentConsoleId
  $parent_uuid = ""
  if ($open_group_list.Count -gt 0) {
    # look at the most recent group, and find its UUID
    $parent_uuid = $open_group_list.Peek().uuid
  } else {
    $parent_uuid = "root"
  }

  $date_time = (Get-Date).ToUniversalTime()
  $group_start_timestamp = [System.Math]::Truncate((Get-Date -Date $date_time -UFormat %s))
  Write-Output ""
  Write-Output "__SH__GROUP__START__|{`"type`":`"grp`",`"sequenceNumber`":`"$group_start_timestamp`",`"id`":`"$group_uuid`",`"is_shown`":`"$is_shown`"}|$group_name"

  $group = [Group]::New()
  $group.name = $group_name
  $group.uuid = $group_uuid
  $group.parent_uuid = $parent_uuid
  $group.shown = $is_shown
  $group.status = 0

  $open_group_list.Push($group)
}

Function execute_command([string]$cmd) {
  $group = [Group]::New()

  if ($open_group_list.Count -gt 0) {
    $group = $open_group_list.Peek()
  }

  $cmd_uuid = [guid]::NewGuid().Guid
  $date_time = (Get-Date).ToUniversalTime()
  $cmd_start_timestamp = [System.Math]::Truncate((Get-Date -Date $date_time -UFormat %s))
  Write-Output "__SH__CMD__START__|{`"type`":`"cmd`",`"sequenceNumber`":`"$cmd_start_timestamp`",`"id`":`"$cmd_uuid`",`"parentConsoleId`": `"$($group.uuid)`"}|$cmd"

  $cmd_status = 0
  $ErrorActionPreference = "Stop"

  Try
  {
    $global:LASTEXITCODE = 0;
    Invoke-Expression $cmd
    $ret = $LASTEXITCODE
    if ($ret -ne 0) {
      $cmd_status = $ret
      Throw
    }
  }
  Catch
  {
    $cmd_status = 1
    Write-Output $_
    Throw
  }
  Finally
  {
    $date_time = (Get-Date).ToUniversalTime()
    $cmd_end_timestamp = [System.Math]::Truncate((Get-Date -Date $date_time -UFormat %s))
    $cmd_first_line = $cmd.Split([Environment]::NewLine) | select -First 1
    Write-Output ""
    Write-Output "__SH__CMD__END__|{`"type`":`"cmd`",`"sequenceNumber`":`"$cmd_end_timestamp`",`"id`":`"$cmd_uuid`",`"exitcode`":`"$cmd_status`"}|$cmd_first_line"
  }
}

Function export_run_variables() {
  if (Test-Path -Path $env:run_dir/workspace/run.env) {
    & $env:run_dir/workspace/run.env
  }
}

Function export_pipeline_variables() {
  if (Test-Path -Path $env:pipeline_workspace_dir/pipeline.env) {
    & $env:pipeline_workspace_dir/pipeline.env
  }
}
