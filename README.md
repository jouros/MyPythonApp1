# MyPythonApp1

Github Actions Workflow CI pipeline lab. I'm using WSL2 Windows host as cloud platform. I'm using Self Hosted Github Actions Runner to execute Github Actions. Runner is configured with Ansible and Docker deployment is rootless, so there is just one regular user account with Docker and Runner. 

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
