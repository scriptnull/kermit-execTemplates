exec_cmd ". $HOME/.nvm/nvm.sh"
exec_cmd "nvm install \"$LANGUAGE_VERSION\""
exec_cmd "nvm use \"$LANGUAGE_VERSION\""
exec_cmd 'node --version'
