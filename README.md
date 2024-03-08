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


Docker is running:
```text
$ export XDG_RUNTIME_DIR="/run/user/1001"
$
$ systemctl --user status docker.service --no-pager
● docker.service - Docker Application Container Engine (Rootless)
     Loaded: loaded (/home/agentuser/.config/systemd/user/docker.service; enabled; vendor preset: enabled)
     Active: active (running) since Thu 2024-03-07 12:39:42 EET; 2h 53min ago
       Docs: https://docs.docker.com/go/rootless/
   Main PID: 750 (rootlesskit)
````


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

### Docker Content Trust keys


#### docker trust key generate

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
        └── 1f3c4beb156fe65bb2fb1a9eb3ec280fce41015e70ee6eb3da082dd396163deb.key 
```

```text
$ docker login --username jrcjoro1
Password:
WARNING! Your password will be stored unencrypted in /home/agentuser/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store
$
$ docker trust signer add --key jorokey.pub jorosigner jrcjoro1/mypythonapp1
Adding signer "jorosigner" to jrcjoro1/mypythonapp1...
Initializing signed repository for jrcjoro1/mypythonapp1...
Enter passphrase for root key with ID 7430b12:
Enter passphrase for new repository key with ID 93b133c:
Repeat passphrase for new repository key with ID 93b133c:
Successfully initialized "jrcjoro1/mypythonapp1"
Successfully added signer: jorosigner to jrcjoro1/mypythonapp1
$
~/.docker$ tree trust/
trust/
├── private
│   ├── 026084ea5d482e43e4a630b9589efa6e2c9761efedc8d984e23c00b10b185cdc.key
│   ├── 7430b129956dd2a016d354eb555bf60908ea2fe37824d1420fb569131a9fd210.key
│   └── 93b133c3b226bf5294b166c0bfd2d1f0193dfff42678cadb906e8c0bcc6969f8.key
└── tuf
    └── docker.io
        └── jrcjoro1
            ├── mypythonapp
            │   ├── changelist
            │   └── metadata
            │       ├── root.json
            │       ├── snapshot.json
            │       ├── targets.json
            │       └── timestamp.json
            └── mypythonapp1
                ├── changelist
                └── metadata
                    ├── root.json
                    └── targets.json
$
$ docker trust inspect --pretty jrcjoro1/mypythonapp1

No signatures for jrcjoro1/mypythonapp1


List of signers and their keys for jrcjoro1/mypythonapp1

SIGNER       KEYS
jorosigner   1f3c4beb156f

Administrative keys for jrcjoro1/mypythonapp1

  Repository Key:       93b133c3b226bf5294b166c0bfd2d1f0193dfff42678cadb906e8c0bcc6969f8
  Root Key:     94a1795e22a745bc1dc3cb98a16bc78e861a2f4ae01deb7bfc58598461bdb2f7
```

In Above 'mypythonapp' is first version which I use for comparison and 'mypythonapp1' is current version which was just created. 



#### Creating delegation key manually


Below I create my own CA, delegation.csr, sign csr with my own CA and create delegation.crt, add new delegation.key to docker trust private and use that new delegation.crt to add new 'newsigner' to repo jrcjoro1/mypythonapp1, which will have now two signers 'jorosigner' and 'newsigner':
```text
$ openssl genrsa -out delegation.key 4096
$
$ ls -la delegation.key
-rw------- 1 agentuser agentuser 3272 Mar  8 11:58 delegation.key
$
$ cat csr.conf
[ req ]
default_bits = 4096
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
C = FI
ST = Helsinki
L = Helsinki
O = jrc
OU = jrc
CN = runner.jrc.local

[ req_ext ]
basicConstraints=CA:FALSE
keyUsage = nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = runner.jrc.local
IP.1 = 192.168.122.15
$
$ openssl req -new -key delegation.key -out delegation.csr -config csr.conf
$
$ openssl req -text -noout -verify -in delegation.csr
Certificate request self-signature verify OK
Certificate Request:
    Data:
        Version: 1 (0x0)
        Subject: C = FI, ST = Helsinki, L = Helsinki, O = jrc, OU = jrc, CN = runner.jrc.local
$
$ openssl req -x509 \
>             -sha256 -days 356 \
>             -nodes \
>             -newkey rsa:4096 \
>             -subj "/CN=runner.jrc.local/C=FI/L=HELSINKI" \
>             -keyout rootCA.key -out rootCA.crt 
$
$ cat cert.conf
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = runner.jrc.local
IP.1 = 192.168.122.15
$
$ openssl x509 -req \
>     -in delegation.csr \
>     -CA rootCA.crt -CAkey rootCA.key \
>     -CAcreateserial -out delegation.crt \
>     -days 1825 \
>     -sha256 -extfile cert.conf
Certificate request self-signature ok
subject=C = FI, ST = Helsinki, L = Helsinki, O = jrc, OU = jrc, CN = runner.jrc.local
$
$ openssl x509 -in delegation.crt -text -noout
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            10:cc:5b:3c:be:ec:72:69:ef:9e:5d:f4:80:45:e2:b7:94:11:9a:c7
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = runner.jrc.local, C = FI, L = HELSINKI
        Validity
            Not Before: Mar  8 10:31:34 2024 GMT
            Not After : Mar  7 10:31:34 2029 GMT
        Subject: C = FI, ST = Helsinki, L = Helsinki, O = jrc, OU = jrc, CN = runner.jrc.local
$
$ docker trust key load delegation.key --name newsigner
Loading key from "delegation.key"...
Enter passphrase for new newsigner key with ID 8eb496d:
Repeat passphrase for new newsigner key with ID 8eb496d:
Successfully imported key from delegation.key
$
$ notary -d ~/.docker/trust key list

ROLE         GUN                          KEY ID                                                              LOCATION
----         ---                          ------                                                              --------
root                                      7430b129956dd2a016d354eb555bf60908ea2fe37824d1420fb569131a9fd210    /home/agentuser/.docker/trust/private
newsigner                                 8eb496d6539a0371e2c817b6f3ace87e21b5df946cad465fe6cc2eefcf9f850c    /home/agentuser/.docker/trust/private
$
$ docker trust signer add --key delegation.crt newsigner jrcjoro1/mypythonapp1
Adding signer "newsigner" to jrcjoro1/mypythonapp1...
Enter passphrase for repository key with ID 93b133c:
Successfully added signer: newsigner to jrcjoro1/mypythonapp1
$
$ docker trust inspect --pretty jrcjoro1/mypythonapp1
jrcjoro1/mypythonapp1
No signatures for jrcjoro1/mypythonapp1


List of signers and their keys for jrcjoro1/mypythonapp1

SIGNER       KEYS
jorosigner   1f3c4beb156f
newsigner    8eb496d6539a

Administrative keys for jrcjoro1/mypythonapp1

  Repository Key:       93b133c3b226bf5294b166c0bfd2d1f0193dfff42678cadb906e8c0bcc6969f8
  Root Key:     94a1795e22a745bc1dc3cb98a16bc78e861a2f4ae01deb7bfc58598461bdb2f7

```


#### Exporting root pub key


```text
$ cat .docker/trust/tuf/docker.io/jrcjoro1/mypythonapp1/metadata/root.json | jq
$ "keytype": "ecdsa-x509" => 94a1795e22a745bc1dc3cb98a16bc78e861a2f4ae01deb7bfc58598461bdb2f7
$
$ BASE64KEY=$(cat .docker/trust/tuf/docker.io/jrcjoro1/mypythonapp1/metadata/root.json | jq '.signed.keys."94a1795e22a745bc1dc3cb98a16bc78e861a2f4ae01deb7bfc58598461bdb2f7".keyval.public' | sed -e 's/^"//' -e 's/"$//')
$
$ echo $BASE64KEY | base64 -d > rootpub.crt
$
$ openssl x509 -in rootpub.crt -pubkey -noout
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE3emk7zw/3/Io7U3uTFHc1QShztwx
...
-----END PUBLIC KEY-----
```


#### Backup all keys


Problems will arise if you loose keys, so keep them safe!


### Cleanup


In Lab environment idea is to play around and be able to start again at any point. With DCT this can be tricky once keys have been created, so easiest way is to initiate new DCT repository and create new keys for that. 


