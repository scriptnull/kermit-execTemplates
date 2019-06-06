#!/bin/bash -e

git_clone() {
  local repositoryName="<%=name%>"
  local cloneLocation="<%=cloneLocation%>"
  local privateKey="<%=privateKey%>"
  local cloneUrl="<%=cloneUrl%>"
  local commitSha="<%=commitSha%>"
  local no_verify_ssl="<%=noVerifySSL%>"

  local privateKeyPath="/tmp/$repositoryName.pem"
  echo "$privateKey" > $privateKeyPath
  chmod 600 $privateKeyPath
  git config --global credential.helper store
  if [ "$no_verify_ssl" == "true" ]; then
    git config --global http.sslVerify false
  fi

  if [ ! -d $HOME/.ssh ]; then
    mkdir -p $HOME/.ssh
    echo "Host *" >> "$HOME/.ssh/config"
    echo "    StrictHostKeyChecking no" >> "$HOME/.ssh/config"
  fi

  # clone git repo
  shippable_retry ssh-agent bash -c "ssh-add $privateKeyPath; git clone $cloneUrl $cloneLocation"

  pushd $cloneLocation
    git config --get user.name || git config user.name 'Shippable Build'
    git config --get user.email || git config user.email 'build@shippable.com'

    checkoutResult=0
    {
      git checkout $commitSha
    } || {
      checkoutResult=$?
    }
    if [ $checkoutResult -ne 0 ]; then
      exit $checkoutResult
    fi

    rm $privateKeyPath
  popd
}

git_clone
