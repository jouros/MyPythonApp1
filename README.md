# MyPythonApp1

Github Actions Workflow CI pipeline lab. I'm using WSL2 Windows host as cloud platform. I'm using Self Hosted Github Actions Runner to execute Github Actions. Runner is configured with Ansible and Docker deployment is Rootless, so there is just one access restricted regular user account for Docker and Runner. 

For Ansible I'm using account 'management' with sudo rights, Runner regular user is 'agentuser'. Ssh Pub key is only allowd for management user. 


## Self Hosted Runner deployment

```text
$ prepare-cloudimage-disk.sh -n jammy-server-cloudimg-amd64 -N 6
Image resized.
image: jammy-server-cloudimg-amd64-50G-6.qcow2
file format: qcow2
virtual size: 50 GiB (53687091200 bytes)
disk size: 1.48 GiB
cluster_size: 65536
Format specific information:
    compat: 1.1
    compression type: zlib
    lazy refcounts: false
    refcount bits: 16
    corrupt: false
    extended l2: false
$
$ ./vm-script-ubuntu-cloudinit.sh -n Runner -d 'Github-actions' -p './jammy-server-cloudimg-amd64-50G-6.qcow2' -N '6'

#################################################
Parameters:

NAME        = Runner
DESCRIPTION = Github-actions
DPATH       = ./jammy-server-cloudimg-amd64-50G-6.qcow2
NUM         = 6

################################################
Starting...
```

#### Rootless Dokcer

From IaC host I run Rootless Docker deployment role and verify result in Selfhostedrunner host:
```text
$ IaC:
$ ansible-playbook main.yml --tags "deploy-docker"
$
agentuser@selfhostedrunner:~$ id
uid=1001(agentuser) gid=1002(agentuser) groups=1002(agentuser),100(users),999(docker)
agentuser@selfhostedrunner:~$ docker info
Client: Docker Engine - Community
 Version:    25.0.3
 Context:    default
 Debug Mode: false
 Plugins:
  buildx: Docker Buildx (Docker Inc.)
    Version:  v0.12.1
    Path:     /usr/libexec/docker/cli-plugins/docker-buildx
  compose: Docker Compose (Docker Inc.)
    Version:  v2.24.5
    Path:     /usr/libexec/docker/cli-plugins/docker-compose

Server:
 Containers: 0
  Running: 0
  Paused: 0
  Stopped: 0
 Images: 0
 Server Version: 25.0.3
```

### Deploy Runner

```text
$ mkdir actions-runner && cd actions-runner
$
$ curl -o actions-runner-linux-x64-2.314.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.314.1/actions-runner-linux-x64-2.314.1.tar.gz
$
$ echo "6c726a118bbe02cd32e222f890e1e476567bf299353a96886ba75b423c1137b5  actions-runner-linux-x64-2.314.1.tar.gz" | shasum -a 256 -c
actions-runner-linux-x64-2.314.1.tar.gz: OK
$
$ tar xzf ./actions-runner-linux-x64-2.314.1.tar.gz
$
$ ./config.sh --url https://github.com/jouros/MyPythonApp1 --token AR73IKE...

--------------------------------------------------------------------------------
|        ____ _ _   _   _       _          _        _   _                      |
|       / ___(_) |_| | | |_   _| |__      / \   ___| |_(_) ___  _ __  ___      |
|      | |  _| | __| |_| | | | | '_ \    / _ \ / __| __| |/ _ \| '_ \/ __|     |
|      | |_| | | |_|  _  | |_| | |_) |  / ___ \ (__| |_| | (_) | | | \__ \     |
|       \____|_|\__|_| |_|\__,_|_.__/  /_/   \_\___|\__|_|\___/|_| |_|___/     |
|                                                                              |
|                       Self-hosted runner registration                        |
|                                                                              |
--------------------------------------------------------------------------------

# Authentication


√ Connected to GitHub

# Runner Registration

Enter the name of the runner group to add this runner to: [press Enter for Default]

Enter the name of runner: [press Enter for selfhostedrunner]

This runner will have the following labels: 'self-hosted', 'Linux', 'X64'
Enter any additional labels (ex. label-1,label-2): [press Enter to skip]

√ Runner successfully added
√ Runner connection is good

# Runner settings

Enter name of work folder: [press Enter for _work]

√ Settings Saved.
```

Runner is running in foreground:
```text
$ ./run.sh

√ Connected to GitHub

Current runner version: '2.314.1'
2024-02-29 11:19:02Z: Listening for Jobs
2024-02-29 12:57:43Z: Running job: build
2024-02-29 12:58:03Z: Job build completed with result: Succeeded
2024-02-29 13:05:52Z: Running job: build
2024-02-29 13:06:04Z: Job build completed with result: Succeeded
2024-02-29 13:11:45Z: Running job: build
```

### Runner workflow yaml

I prefer to have debug logs enabled when I develop pipeline yaml, so I set repository secret 'ACTIONS_STEP_DEBUG' with value 'true' in repository settings and verify that setting in yaml env variables printout `echo "RUNNER_DEBUG: $RUNNER_DEBUG"` which will have value '1' when debug is on. 


### Trivy image security scanning tool

```text
$ ansible-playbook main.yml --tags "deploy-imagescan"
TASK [deploy-imagescan : debug] ***************************************************************************************************************************************************************************************************
Friday 01 March 2024  15:23:06 +0200 (0:00:01.517)       0:00:04.678 **********
ok: [selfhostedrunner] =>
  msg: |-
    Selecting previously unselected package trivy.
    (Reading database ... 101503 files and directories currently installed.)
    Preparing to unpack /home/management/trivy.dep ...
    Unpacking trivy (0.49.1) ...
    Setting up trivy (0.49.1) ...
```

### Docker Content Trust


First I'll create delegation key. Delegation is key who control can sign a image tag:
```text
$ docker trust key generate jorokey
Generating key for jorokey...
Enter passphrase for new jorokey key with ID 7608e6e:
Passphrase is too short. Please use a password manager to generate and store a good random passphrase.
Enter passphrase for new jorokey key with ID 7608e6e:
Repeat passphrase for new jorokey key with ID 7608e6e:
Successfully generated and loaded private key. Corresponding public key available: /home/agentuser/jorokey.pub
$
```

Above command will add private key automatically to trust store:
```text
$ tree .docker/

└── trust
    └── private
        └── 7608e6e556b0d54092ef541f6613ea894f0602a3b684bcc424997dda32fb7cbb.key
```


