Function replace_placeholders() {
    $versionPath = "<%= obj.versionPath %>"
    if (Test-Path "$versionPath") {
        exec_cmd "shippable_replace $versionPath"
    }
}

replace_placeholders
