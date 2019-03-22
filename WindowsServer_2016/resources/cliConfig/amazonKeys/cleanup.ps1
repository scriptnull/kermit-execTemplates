$ErrorActionPreference = "Stop"

$rootDir = "$PSScriptRoot\..\..\.."
$commonDir = Join-Path "$rootDir" "\resources\common"
$helpersPath = Join-Path "$commonDir" "_helpers.ps1"
$loggerPath = Join-Path "$commonDir" "_logger.ps1"
$scriptName = $MyInvocation.InvocationName

. "$loggerPath"
. "$helpersPath"

function help() {
@"
Usage:
    $scriptName <resource_name> [scopes]
"@
}

function cleanup_scope_configure() {
    _log_msg "Cleaning up scope configure"

    $awsConfigPath = "~/.aws"

    if (Test-Path -PathType Container "$awsConfigPath") {
        Remove-Item -Force -Recurse "$awsConfigPath"
    }

    _log_success "Successfully cleaned up scope configure"
}

function cleanup_scope_ecr() {
    # TODO: Figure out how to logout of all registries. Just deleting
    # ~/.docker is not going to do anything useful because the creds
    # are actually stored in the Windows Credential Manager

    _log_msg "ecr scope cleanup is not yet supported on Windows"
}

function cleanup([string] $resourceName, [string] $scopes) {
    _log_grp "Cleaning up resource $resourceName"

    cleanup_scope_configure

    if (_csv_has_value $scopes "ecr") {
        cleanup_scope_ecr
    }
}

function main() {
    if ($args.Length -gt 0) {
        if ($args[0] -eq "help") {
            help
            exit 0
        } else {
            cleanup @args
        }
    } else {
        help
        exit 1
    }
}

main @args