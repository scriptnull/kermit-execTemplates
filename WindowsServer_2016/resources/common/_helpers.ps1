$ErrorActionPreference = "Stop"

function _csv_has_value([string] $csv, [string] $value) {
    return $csv -match "(^|,)$value(,|$)"
}