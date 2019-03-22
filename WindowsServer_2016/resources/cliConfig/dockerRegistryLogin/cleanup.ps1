$ErrorActionPreference = "Stop"

$rootDir = "$PSScriptRoot\..\..\.."
$commonDir = Join-Path "$rootDir" "\resources\common"
$helpersPath = Join-Path "$commonDir" "_helpers.ps1"
$loggerPath = Join-Path "$commonDir" "_logger.ps1"
$scriptName = $MyInvocation.InvocationName

. "$loggerPath"
. "$helpersPath"

$resourceName = ""
$registryUrl = ""

function help() {
@"
Usage:
    $scriptName <resource_name> [scopes]
"@
}

function cleanup_scope_configure() {
    _log_msg "Cleaning up scope configure"

    docker logout "$registryUrl"
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    _log_success "Successfully cleaned up scope configure"
}

function cleanup([string] $resourceName) {
    $script:resourceName = $resourceName
    $script:registryUrl = shipctl get_integration_resource_field "$script:resourceName" "url"

    _log_grp "Cleaning up resource $resourceName"
    cleanup_scope_configure
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