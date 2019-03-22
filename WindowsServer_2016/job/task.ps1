Function init_integrations() {
  <% if (obj.integrationInitScripts.length > 0) { %>
    exec_cmd 'echo "Initializing CLI integrations"'
    <% _.each(obj.integrationInitScripts, function (integrationInitScript) { %>
    <%= integrationInitScript %>
    <% }); %>
  <% } %>
}

Function cleanup_integrations() {
  <% if (obj.integrationCleanupScripts.length > 0) { %>
    exec_cmd 'echo "Cleaning CLI integrations"'
    <% _.each(obj.integrationCleanupScripts, function (integrationCleanupScript) { %>
    <%= integrationCleanupScript %>
    <% }); %>
  <% } %>
}

Function Fail-ShippableBuild() {
  $global:FAIL_SHIPPABLE_BUILD = $TRUE
  Throw "Fail-ShippableBuild called in script"
}

Function install_shipctl() {
  $NODE_DIR = "C:\Users\Administrator\Shippable\node"
  $shipctlScriptsPath = "$NODE_DIR\shipctl\$env:SHIPPABLE_NODE_ARCHITECTURE\$env:SHIPPABLE_NODE_OPERATING_SYSTEM\install.ps1"
  if (Test-Path -PathType leaf "$shipctlScriptsPath") {
    exec_cmd "Write-Output 'Installing shipctl components'"
    Try
    {
      & "$shipctlScriptsPath"
    }
    Catch
    {
      Write-Output $_
    }
  }
}

Function task() {
  install_shipctl
  init_integrations
  <% _.each(obj.script, function(cmd) { %>
exec_cmd @'
<%= cmd %>
'@
  <% }) %>
  cleanup_integrations
}

<% if (obj.onSuccess) { %>
Function on_success() {
  <% _.each(obj.onSuccess.script, function(cmd) { %>
    Try
    {
Invoke-Expression @'
<%= cmd %>
'@
    }
    Catch
    {
      Write-Output $_
      if ($global:FAIL_SHIPPABLE_BUILD) {
        return
      }
    }
  <% }); %>
}
<% } %>

<% if (obj.onFailure) { %>
Function on_failure() {
  <% _.each(obj.onFailure.script, function(cmd) { %>
    Try
    {
Invoke-Expression @'
<%= cmd %>
'@
    }
    Catch
    {
      Write-Output $_
      if ($global:FAIL_SHIPPABLE_BUILD) {
        return
      }
    }
  <% }); %>
}
<% } %>

<% if (obj.always) { %>
Function always() {
  <% _.each(obj.always.script, function(cmd) { %>
    Try
    {
Invoke-Expression @'
<%= cmd %>
'@
    }
    Catch
    {
      Write-Output $_
      if ($global:FAIL_SHIPPABLE_BUILD) {
        return
      }
    }
  <% }); %>
}
<% } %>

Function before_exit() {
  if ($global:is_success) {
    <% if (obj.onSuccess && !_.isEmpty(obj.onSuccess.script)) { %>
      exec_cmd "on_success"
    <% } %>

    <% if (obj.always && !_.isEmpty(obj.always.script)) { %>
      exec_cmd "always"
    <% } %>

    if ($env:current_grp_uuid) {
      $date_time = (Get-Date).ToUniversalTime()
      $current_timestamp = [System.Math]::Truncate((Get-Date -Date $date_time -UFormat %s))

      $group_status = 0
      if ($global:FAIL_SHIPPABLE_BUILD) {
        $group_status = 1
      }

      Write-Output "__SH__GROUP__END__|{`"type`":`"grp`",`"sequenceNumber`":`"$current_timestamp`",`"id`":`"$env:current_grp_uuid`",`"is_shown`":`"false`",`"exitcode`":`"$group_status`"}|$env:current_grp"
    }

    if ($global:FAIL_SHIPPABLE_BUILD) {
      Write-Output "__SH__SCRIPT_END_FAILURE__";
    } else {
      Write-Output "__SH__SCRIPT_END_SUCCESS__";
    }
  } else {
    <% if (obj.onFailure && !_.isEmpty(obj.onFailure.script)) { %>
      exec_cmd "on_failure"
    <% } %>

    <% if (obj.always && !_.isEmpty(obj.always.script)) { %>
      exec_cmd "always"
    <% } %>

    if ($env:current_grp_uuid) {
      $date_time = (Get-Date).ToUniversalTime()
      $current_timestamp = [System.Math]::Truncate((Get-Date -Date $date_time -UFormat %s))
      $group_status = 1

      Write-Output "__SH__GROUP__END__|{`"type`":`"grp`",`"sequenceNumber`":`"$current_timestamp`",`"id`":`"$env:current_grp_uuid`",`"is_shown`":`"false`",`"exitcode`":`"$group_status`"}|$env:current_grp"
    }

    Write-Output "__SH__SCRIPT_END_FAILURE__";
  }
}

Function main() {
  $global:is_success = $TRUE
  Try
  {
    exec_grp "task" "Executing Task: $env:TASK_NAME" $TRUE $FALSE
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
