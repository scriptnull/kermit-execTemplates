$open_group_list = New-Object System.Collections.Stack
$open_group_info = @{}

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
  $group_name = $open_group_list.Peek()
  $group = $open_group_info[$group_name]

  $date_time = (Get-Date).ToUniversalTime()
  $group_end_timestamp = [System.Math]::Truncate((Get-Date -Date $date_time -UFormat %s))

  echo "__SH__GROUP__END__|{\"type\":\"grp\",\"sequenceNumber\":\"$group_end_timestamp\",\"id\":\"$group.uuid\",\"is_shown\":\"$group.shown\",\"exitcode\":\"$group.status\",\"parentConsoleId\":\"$group.parent_uuid\"}|$group.name"

  $open_group_list.Pop()
  $open_group_info.Remove($group_name)
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
    $parent_group_name = $open_group_list.Peek()
    $parent_uuid = $open_group_info[$parent_group_name]
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

  $open_group_list.Push($group.name)
  $open_group_info.Add($group.name, $group)
}

Function execute_command() {

}
