# Contributing

## Resource Files
- These are used to setup a Shippable resource.
- Two files should be defined `init.sh` and `cleanup.sh` in the following structure for every resource and integration master name combination:
  ```
  ├── <os>
  │   └── resources
  │       ├── <resourceType>
  │       │   ├── <integrationMasterName>
  │       │   │   ├── cleanup.sh
  │       │   │   └── init.sh
  ```

## Job Files
- These are templates used to generate a runSh job script:
  ```
  ├── <os>
  │   └── job
  │   │   ├── boot.sh
  │   │   ├── envs.sh
  │   │   ├── header.sh
  │   │   └── task.sh
  ```

## Linting
- Install [shellcheck](https://github.com/koalaman/shellcheck) and run the liniting command found in `shippable.yml`.
