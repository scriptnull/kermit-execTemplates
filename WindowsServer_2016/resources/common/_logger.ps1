# These helpers use [Console]::Write because Write-Output will always add
# new lines between each parameter

$ErrorActionPreference = "Stop"

function _log_grp() {
    # Concat a string so the array gets formatted like we want it to be
    [Console]::WriteLine("" + $args)
}

function _log_msg() {
    [Console]::WriteLine("|___ " + $args)
}

function _log_err() {
    # TODO: Figure out a way to get colours
    _log_msg @args
}

function _log_success() {
    # TODO: Figure out a way to get colours
    _log_msg @args
}