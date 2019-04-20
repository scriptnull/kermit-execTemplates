export H_FLAG_UNSET=false
if [[ $(echo $-) == **H** ]]; then
  export H_FLAG_UNSET=true;
  set +H
fi
start_group "Exporting envs" "false"
