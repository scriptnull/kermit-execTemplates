# execTemplates

This project contains all the script templates that are used to execute a build
on Shippable. [ReqProc](https://github.com/Shippable/kermit-reqProc) combines the generic
templates present in this project with build data to generate
build-specific `bash` scripts. These scripts are eventually executed by [reqExec](https://github.com/Shippable/reqExec)
either on the build node or inside a Docker container.
