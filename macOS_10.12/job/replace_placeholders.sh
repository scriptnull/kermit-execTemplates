
replace_placeholders() {
  VERSION_PATH=<%= obj.versionPath %>
  if [ -f "$VERSION_PATH" ]; then
    {
      exec_cmd "shippable_replace $VERSION_PATH"
    } || true
  fi
}

replace_placeholders
