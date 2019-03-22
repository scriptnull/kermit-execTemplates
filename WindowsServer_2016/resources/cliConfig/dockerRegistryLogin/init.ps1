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
$registryUsername = ""
$registryPassword = ""

function help() {
@"
Usage:
    $scriptName <resource_name> [scopes]
"@
}

function check_params() {
    _log_msg "Checking params"

    $script:registryUrl = shipctl get_integration_resource_field "$script:resourceName" "url"
    $script:registryUsername = shipctl get_integration_resource_field "$script:resourceName" "username"
    $script:registryPassword = shipctl get_integration_resource_field "$script:resourceName" "password"

    if (-not "$script:registryUsername") {
        _log_err "Missing 'userName' value in $script:resourceName integration."
        exit 1
    }

    if (-not "$script:registryPassword") {
        _log_err "Missing 'password' value in $script:resourceName integration."
        exit 1
    }

    _log_success "Successfully checked params"
}

function init_scope_configure() {
    _log_msg "Initializing scope configure"

    docker login -u "$registryUsername" -p "$registryPassword" "$registryUrl"
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    _log_success "Successfully initialized scope configure"
}

function init([string] $resourceName) {
    $script:resourceName = $resourceName

    _log_grp "Initializing Docker registry login for resource $resourceName"

    check_params
    init_scope_configure
}

function main() {
    if ($args.Length -gt 0) {
        if ($args[0] -eq "help") {
            help
            exit 0
        } else {
            init @args
        }
    } else {
        help
        exit 1
    }
}

main @args