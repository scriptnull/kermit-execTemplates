export_pipeline_variables
export_run_variables

stop_group
if $H_FLAG_UNSET; then
  set -H
fi
unset H_FLAG_UNSET
