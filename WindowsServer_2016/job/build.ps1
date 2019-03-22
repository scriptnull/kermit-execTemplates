Function main([string] $scriptPath, [string] $envsPath) {
  <%= obj.reqExecCommand %> "$scriptPath" "$envsPath"
  exit $LASTEXITCODE
}

main @args
