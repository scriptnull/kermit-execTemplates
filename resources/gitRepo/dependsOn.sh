git_sync() {
  local resourceName="$1"
  local resourcePath=$(eval echo "$"res_"$resourceName"_resourcePath)
  pushd $resourcePath
    local scmName=$(eval echo "$"res_"$resourceName"_masterName)
    local isPrivateRepository=$(eval echo "$"res_"$resourceName"_isPrivateRepository)
    local privateKeyVar="res_""$resourceName""_sysPrivateDeployKey"
    local privateKey=$(echo "${!privateKeyVar}")
    local httpCloneUrl=$(eval echo "$"res_"$resourceName"_gitRepoRepositoryHttpsUrl)
    local sshCloneUrl=$(eval echo "$"res_"$resourceName"_gitRepoRepositorySshUrl)
    local commitSha=$(eval echo "$"res_"$resourceName"_commitSha)
    local beforeCommitSha=$(eval echo "$"res_"$resourceName"_beforeCommitSha)
    local branchName=$(eval echo "$"res_"$resourceName"_branchName)
    local isPullRequest=$(eval echo "$"res_"$resourceName"_isPullRequest)
    local isPullRequestClose=$(eval echo "$"res_"$resourceName"_isPullRequestClose)
    local pullRequestNumber=$(eval echo "$"res_"$resourceName"_pullRequestNumber)
    local pullRequestSourceUrl=$(eval echo "$"res_"$resourceName"_pullRequestSourceUrl)
    local shallowDepth=$(eval echo "$"res_"$resourceName"_shallowDepth)
    if [ -z "$shallowDepth" ] || [ "$shallowDepth" == "null" ]; then
      unset shallowDepth
    fi

    if $isPrivateRepository; then
      local cloneUrl=$sshCloneUrl
    else
      local cloneUrl=$httpCloneUrl
    fi

    local privateKeyPath="$STEP_TMP_DIR/$resourceName.pem"
    echo "$privateKey" > $privateKeyPath
    chmod 600 $privateKeyPath
    git config --global credential.helper store
    if [ "$NO_VERIFY_SSL" == "true" ]; then
      git config --global http.sslVerify false
    fi

    echo 'ssh -o StrictHostKeyChecking=no $*' > "$STEP_TMP_DIR/${resourceName}ssh"
    chmod +x "$STEP_TMP_DIR/${resourceName}ssh"

    # clone git repo
    local gitCloneCmd="git clone $cloneUrl $resourcePath"
    if [ ! -z $shallowDepth ]; then
      gitCloneCmd="git clone --no-single-branch --depth $shallowDepth $cloneUrl $resourcePath"
    fi
    retry_command ssh-agent bash -c "ssh-add $privateKeyPath; GIT_SSH="$STEP_TMP_DIR/${resourceName}ssh" $gitCloneCmd"

    git config --get user.name || git config user.name 'Shippable Build'
    git config --get user.email || git config user.email 'build@shippable.com'

    if $isPullRequest; then
      if [ "$scmName" == "github" ]; then
        local gitFetchCmd="git fetch origin pull/$pullRequestNumber/head"
        if [ ! -z $shallowDepth ]; then
          gitFetchCmd="git fetch --depth $shallowDepth origin pull/$pullRequestNumber/head"
        fi
        retry_command ssh-agent bash -c "ssh-add $privateKeyPath; GIT_SSH="$STEP_TMP_DIR/${resourceName}ssh" $gitFetchCmd"
        git checkout -f FETCH_HEAD
        local mergeResult=0
        {
          git merge origin/$branchName
        } || {
          mergeResult=$?
        }
        if [ $mergeResult -ne 0 ]; then
          if [ ! -z $shallowDepth ]; then
            {
              git rev-list FETCH_HEAD | grep $beforeCommitSha >> /dev/null 2>&1
            } || {
              echo "The PR was fetched with depth $shallowDepth, but the base commit $beforeCommitSha is not present. Please try increasing the depth setting on your project."
            }
          fi
          exit $mergeResult
        fi
      elif [ "$scmName" == "bitbucket" ] || [ "$scmName" == "bitbucketServerBasic" ]; then
        if [ "$cloneUrl" != "$pullRequestSourceUrl" ]; then
          git remote add PR $pullRequestSourceUrl
          local git_fetch_cmd="git fetch PR"
          if [ ! -z "$shallowDepth" ]; then
            git_fetch_cmd="git fetch --depth $shallowDepth PR"
          fi
          retry_command ssh-agent bash -c "ssh-add $privateKeyPath; GIT_SSH="$STEP_TMP_DIR/${resourceName}ssh" $git_fetch_cmd"
        fi;
        reset_result=0
        {
          git reset --hard $commitSha
        } || {
          reset_result=$?
        }
        if [ $reset_result -ne 0 ]; then
          if [ ! -z "$shallowDepth" ]; then
            {
              git rev-list HEAD | grep $commitSha >> /dev/null 2>&1
            } || {
              echo "The PR was fetched with depth $shallowDepth, but the commit $commitSha is not present. Please try increasing the depth setting on your project."
            }
          fi
          exit $reset_result
        fi
        merge_result=0
        {
          git merge origin/$branchName
        } || {
          merge_result=$?
        }
        if [ $merge_result -ne 0 ]; then
          if [ ! -z "$shallowDepth" ]; then
            {
              git rev-list HEAD | grep $beforeCommitSha >> /dev/null 2>&1
            } || {
              echo "The PR was fetched with depth $shallowDepth, but the base commit $beforeCommitSha is not present. Please try increasing the depth setting on your project."
            }
          fi
          exit $merge_result
        fi
      else
        echo "Pull requests not supported for $scmName"
        exit 1
      fi
    else
      checkoutResult=0
      {
        git checkout $commitSha
      } || {
        checkoutResult=$?
      }
      if [ $checkoutResult -ne 0 ]; then
        if [ ! -z "$shallowDepth" ]; then
          {
            git cat-file -t $commitSha >> /dev/null 2>&1
          } || {
            echo "The repository was cloned with depth $shallowDepth, but the commit $commitSha is not present in this depth. Please increase the depth to run this build."
          }
        fi
        exit $checkoutResult
      fi
    fi
    rm $privateKeyPath
    jfrog rt bag $PIPELINE_NAME $RUN_NUMBER
  popd
}

execute_command "git_sync %%context.resourceName%%"
