export %%context.key%%=%%context.value%%
if [ "%%context.isReadOnly%%" == "true" ]; then
  readonly %%context.key%%
fi
