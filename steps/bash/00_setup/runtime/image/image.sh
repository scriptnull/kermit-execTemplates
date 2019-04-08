if [ "$(type -t auto)" == "function" ]; then
  auto
fi

if [ "$(type -t custom)" == "function" ]; then
  custom
fi
