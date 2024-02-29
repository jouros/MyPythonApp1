# MyPythonApp1

Github Actions Workflow CI pipeline lab. I'm using WSL2 Windows host as cloud platform. I'm using Self Hosted Github Actions Runner to execute Github Actions. Runner is configured with Ansible and Docker deployment is rootless, so there is just one access restricted regular user account with Docker and Runner. 

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

