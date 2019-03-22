$ErrorActionPreference = "Stop"

$rootDir = "$PSScriptRoot\..\..\.."
$commonDir = Join-Path "$rootDir" "\resources\common"
$helpersPath = Join-Path "$commonDir" "_helpers.ps1"
$loggerPath = Join-Path "$commonDir" "_logger.ps1"
$scriptName = $MyInvocation.InvocationName

. "$loggerPath"
. "$helpersPath"

$resourceName = ""
$scopes = ""
$awsAccessKey = ""
$awsSecretKey = ""
$resourceVersionPath = ""
$awsRegion = ""

function help() {
@"
Usage:
    $scriptName <resource_name> [scopes]
"@
}

function check_params() {
    $script:awsAccessKey = shipctl get_integration_resource_field "$resourceName" "accessKey"
    $script:awsSecretKey = shipctl get_integration_resource_field "$resourceName" "secretKey"
    $script:resourceVersionpath = (shipctl get_resource_meta "$resourceName") + "/version.json"
    $script:awsRegion = shipctl get_json_value $resourceVersionPath "version.propertyBag.region"

    if (-not "$script:awsAccessKey") {
        _log_err "Missing 'accessKey' value in $resourceName integration"
        exit 1
    }

    if (-not "$script:awsSecretKey") {
        _log_err "Missing 'secretKey' value in $resourceName integration"
        exit 1
    }

    if (-not "$script:awsRegion") {
        _log_err "Missing 'region' value in $resourceName integration"
        exit 1
    }

    _log_success "Successfully checked params"
}

function init_scope_configure() {
    _log_msg "Initializing scope configure"

    & aws configure set aws_access_key_id $awsAccessKey
    & aws configure set aws_secret_access_key $awsSecretKey
    & aws configure set region $awsRegion

    _log_success "Successfully initialized scope configure"
}

function init_scope_ecr() {
    _log_msg "Initializing scope ecr"
    $dockerLoginCommand = (aws ecr get-login --no-include-email)
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    Invoke-Expression $dockerLoginCommand
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    _log_msg "Successfully initialized scope ecr"
}

function init([string] $resourceName, [string] $scopes) {
    $script:resourceName = $resourceName
    $script:scopes = $scopes

    _log_grp "Initializing AWS keys for resource $resourceName"

    check_params

    init_scope_configure

    if (_csv_has_value "$scopes" "ecr") {
        init_scope_ecr
    }
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