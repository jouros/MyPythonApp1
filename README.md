# MyPythonApp1


Github Actions Workflow CI/CD pipeline lab with Container digital signatures (Docker Content Trust), Container security scanning (Aquasecurity Trivy), OCI Helm Charts, signature verification (Connaisseur), Hashi Vault integration and CD pipeline automation with Flux.

I'm using WSL2 Windows host as cloud platform. I'm using Self Hosted Github Actions Runner to execute Github Actions. Runner is configured with Ansible and Docker deployment is Rootless, so there is just one access restricted regular user account for Docker and Runner.

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

### Rootless Dokcer

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


## CI Pipeline and Docker Content Trust


### docker trust key generate

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


### Creating delegation key manually


#### rsa-x509

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


#### Docker default ecdsa key

Unfortunately Connaisseur does not support rsa-x509 keys in Chart version 2.3.4 / App vversion 3.3.4, so Connaisseur config you have to use Docker default generated root pub key. They mentioned in github discussion board that support for rsa-x509 is under delelopment and will be added later on. Connaisseur error related to key format is:
```text
Error: INSTALLATION FAILED: 1 error occurred:
        * admission webhook "connaisseur-svc.connaisseur.svc" denied the request: Trust data targets has an invalid format: 'rsa-x509' is not one of ['ecdsa']
```


Generate Docker default ecdsa key:
```text
$ docker trust key generate newsigner2
Generating key for newsigner2...
Enter passphrase for new newsigner2 key with ID 795f9ec:
Repeat passphrase for new newsigner2 key with ID 795f9ec:
Successfully generated and loaded private key. Corresponding public key available: /home/agentuser/newsigner2.pub
```

Above will automatically add priv key to ~/.docker/trust/private/ and pub key is in /home/agentuser/newsigner2.pub as cmd output say. 

First I load new priv key:
```text
$ docker trust key load --name newsigner2 ~/.docker/trust/private/795f9ecaea5e8425e8e1d011566970536fbfff6a686327b1b08de4b18bec8cc2.key
Loading key from "/home/agentuser/.docker/trust/private/795f9ecaea5e8425e8e1d011566970536fbfff6a686327b1b08de4b18bec8cc2.key"...
Enter passphrase for encrypted key:
Successfully imported key from /home/agentuser/.docker/trust/private/795f9ecaea5e8425e8e1d011566970536fbfff6a686327b1b08de4b18bec8cc2.key
```

Next I'll have to log in to docker, or I'll get permission error when trying to add new signer:
```text
$ docker trust signer add --key newsigner2.pub newsigner2 docker.io/jrcjoro1/mypythonapp1
Adding signer "newsigner2" to docker.io/jrcjoro1/mypythonapp1...
Enter passphrase for repository key with ID 93b133c:
Passphrase incorrect. Please retry.
Enter passphrase for repository key with ID 93b133c:
you are not authorized to perform this operation: server returned 401.

failed to add signer to: docker.io/jrcjoro1/mypythonapp1
$
$ docker login --username jrcjoro1
Password:
WARNING! Your password will be stored unencrypted in /home/agentuser/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
```

Now I can successfully execute signer add:
```text
$ docker trust signer add --key newsigner2.pub newsigner2 docker.io/jrcjoro1/mypythonapp1
Adding signer "newsigner2" to docker.io/jrcjoro1/mypythonapp1...
Enter passphrase for repository key with ID 93b133c:
Successfully added signer: newsigner2 to docker.io/jrcjoro1/mypythonapp1
```

New signer is on list:
```text
$ docker trust inspect --pretty jrcjoro1/mypythonapp1

Signatures for jrcjoro1/mypythonapp1

SIGNED TAG                                 DIGEST                                                             SIGNERS
59e4d39fb31b20be1ded800fe4e0a55492af47f6   e87e088c8b335b6cedf12d5cdd720c8900ea4d214fb0a1a8fb5ec8e90b8f51ba   newsigner
71e65392cd63a9673da21fdefa618772fdff25ee   e87e088c8b335b6cedf12d5cdd720c8900ea4d214fb0a1a8fb5ec8e90b8f51ba   newsigner
6954f2de0a2bc312b7e527cc7dd57afcad1e87ad   e87e088c8b335b6cedf12d5cdd720c8900ea4d214fb0a1a8fb5ec8e90b8f51ba   newsigner
d2c284704a2e6010c70cdff71cc34a3433a1083a   9171446e3dfba232cb70bbac39b69baa89cb28e24cc3ef0e53acc096f3f287b5   newsigner
f183e6894cae149b2670bdb32d14172affc8da1b   e87e088c8b335b6cedf12d5cdd720c8900ea4d214fb0a1a8fb5ec8e90b8f51ba   newsigner

List of signers and their keys for jrcjoro1/mypythonapp1

SIGNER       KEYS
jorosigner   1f3c4beb156f
newsigner    8eb496d6539a
newsigner2   795f9ecaea5e

Administrative keys for jrcjoro1/mypythonapp1

  Repository Key:       93b133c3b226bf5294b166c0bfd2d1f0193dfff42678cadb906e8c0bcc6969f8
  Root Key:     94a1795e22a745bc1dc3cb98a16bc78e861a2f4ae01deb7bfc58598461bdb2f7
```



### DCT in CI Pipeline

CI pipeline is based on github Actions which run in my selfhosted Runner host. I have set some keys and initialized repo jrcjoro/mypythonapp1 before CI pipeline, so in github Actions yaml I'll just load key, add signer, build and sign Container. Below is situation after first DCT run, where TAG 'd2c...' has been signed by 'newsigner':
```text
$ docker trust inspect --pretty jrcjoro1/mypythonapp1

Signatures for jrcjoro1/mypythonapp1

SIGNED TAG                                 DIGEST                                                             SIGNERS
d2c284704a2e6010c70cdff71cc34a3433a1083a   9171446e3dfba232cb70bbac39b69baa89cb28e24cc3ef0e53acc096f3f287b5   newsigner

List of signers and their keys for jrcjoro1/mypythonapp1

SIGNER       KEYS
jorosigner   1f3c4beb156f
newsigner    8eb496d6539a

Administrative keys for jrcjoro1/mypythonapp1

  Repository Key:       93b133c3b226bf5294b166c0bfd2d1f0193dfff42678cadb906e8c0bcc6969f8
  Root Key:     94a1795e22a745bc1dc3cb98a16bc78e861a2f4ae01deb7bfc58598461bdb2f7
```


Remove signer:
```text
$ docker trust inspect --pretty jrcjoro1/mypythonapp1

Signatures for jrcjoro1/mypythonapp1

SIGNED TAG                                 DIGEST                                                             SIGNERS
59e4d39fb31b20be1ded800fe4e0a55492af47f6   e87e088c8b335b6cedf12d5cdd720c8900ea4d214fb0a1a8fb5ec8e90b8f51ba   newsigner
71e65392cd63a9673da21fdefa618772fdff25ee   e87e088c8b335b6cedf12d5cdd720c8900ea4d214fb0a1a8fb5ec8e90b8f51ba   newsigner
6954f2de0a2bc312b7e527cc7dd57afcad1e87ad   e87e088c8b335b6cedf12d5cdd720c8900ea4d214fb0a1a8fb5ec8e90b8f51ba   newsigner
d2c284704a2e6010c70cdff71cc34a3433a1083a   9171446e3dfba232cb70bbac39b69baa89cb28e24cc3ef0e53acc096f3f287b5   newsigner
f183e6894cae149b2670bdb32d14172affc8da1b   e87e088c8b335b6cedf12d5cdd720c8900ea4d214fb0a1a8fb5ec8e90b8f51ba   newsigner

List of signers and their keys for jrcjoro1/mypythonapp1

SIGNER       KEYS
jorosigner   1f3c4beb156f
newsigner    8eb496d6539a
newsigner2   795f9ecaea5e
...
$
$ docker trust signer remove newsigner2 jrcjoro1/mypythonapp1
Removing signer "newsigner2" from jrcjoro1/mypythonapp1...
Enter passphrase for repository key with ID 93b133c:
you are not authorized to perform this operation: server returned 401.
$
$ docker login --username jrcjoro1
$
$ docker trust signer remove newsigner2 jrcjoro1/mypythonapp1
Removing signer "newsigner2" from jrcjoro1/mypythonapp1...
Enter passphrase for repository key with ID 93b133c:
Successfully removed newsigner2 from jrcjoro1/mypythonapp1
$
$ docker trust inspect --pretty jrcjoro1/mypythonapp1

Signatures for jrcjoro1/mypythonapp1

SIGNED TAG                                 DIGEST                                                             SIGNERS
59e4d39fb31b20be1ded800fe4e0a55492af47f6   e87e088c8b335b6cedf12d5cdd720c8900ea4d214fb0a1a8fb5ec8e90b8f51ba   newsigner
71e65392cd63a9673da21fdefa618772fdff25ee   e87e088c8b335b6cedf12d5cdd720c8900ea4d214fb0a1a8fb5ec8e90b8f51ba   newsigner
6954f2de0a2bc312b7e527cc7dd57afcad1e87ad   e87e088c8b335b6cedf12d5cdd720c8900ea4d214fb0a1a8fb5ec8e90b8f51ba   newsigner
d2c284704a2e6010c70cdff71cc34a3433a1083a   9171446e3dfba232cb70bbac39b69baa89cb28e24cc3ef0e53acc096f3f287b5   newsigner
f183e6894cae149b2670bdb32d14172affc8da1b   e87e088c8b335b6cedf12d5cdd720c8900ea4d214fb0a1a8fb5ec8e90b8f51ba   newsigner

List of signers and their keys for jrcjoro1/mypythonapp1

SIGNER       KEYS
jorosigner   1f3c4beb156f
newsigner    8eb496d6539a
...
```

Above operation does not remove priv key from ~/.docker/trust/private/ so signer and key can be returned also:
```text
$ cat ~/.docker/trust/private/795f9ecaea5e8425e8e1d011566970536fbfff6a686327b1b08de4b18bec8cc2.key
-----BEGIN ENCRYPTED PRIVATE KEY-----
role: newsigner2

MIHuMEkGC...
$

```


### Notary examples


```text
$ notary -s https://notary.docker.io -d ~/.docker/trust list docker.io/jrcjoro1/mypythonapp1
NAME                                        DIGEST                                                              SIZE (BYTES)    ROLE
----                                        ------                                                              ------------    ----
d2c284704a2e6010c70cdff71cc34a3433a1083a    9171446e3dfba232cb70bbac39b69baa89cb28e24cc3ef0e53acc096f3f287b5    1990            targets/releases
$
$ notary -s https://notary.docker.io -d ~/.docker/trust list docker.io/jrcjoro1/mypythonapp1 --roles targets/newsigner
NAME                                        DIGEST                                                              SIZE (BYTES)    ROLE
----                                        ------                                                              ------------    ----
d2c284704a2e6010c70cdff71cc34a3433a1083a    9171446e3dfba232cb70bbac39b69baa89cb28e24cc3ef0e53acc096f3f287b5    1990            targets/newsigner
$
$ notary -s https://notary.docker.io -d ~/.docker/trust delegation list docker.io/jrcjoro1/mypythonapp1

ROLE                  PATHS             KEY IDS                                                             THRESHOLD
----                  -----             -------                                                             ---------
targets/jorosigner    "" <all paths>    1f3c4beb156fe65bb2fb1a9eb3ec280fce41015e70ee6eb3da082dd396163deb    1
targets/newsigner     "" <all paths>    8eb496d6539a0371e2c817b6f3ace87e21b5df946cad465fe6cc2eefcf9f850c    1
targets/newsigner2    "" <all paths>    950ec70deaca8bc2f0590fc19f88626fec7e0bfd77be63f3b2764b43f249fa94    1
targets/releases      "" <all paths>    1f3c4beb156fe65bb2fb1a9eb3ec280fce41015e70ee6eb3da082dd396163deb    1
                                        8eb496d6539a0371e2c817b6f3ace87e21b5df946cad465fe6cc2eefcf9f850c
                                        950ec70deaca8bc2f0590fc19f88626fec7e0bfd77be63f3b2764b43f249fa94
$
$ Fix for error where delegation file is not sidned by any currently valid keys: 
$
$ docker trust inspect --pretty jrcjoro1/mypythonapp1
WARN[0002] Error getting targets/releases: valid signatures did not meet threshold for targets/releases
$
$ notary -s https://notary.docker.io -d ~/.docker/trust witness docker.io/jrcjoro1/mypythonapp1 targets/releases --publish
The following roles were successfully marked for witnessing on the next publish:
        - targets/releases
Auto-publishing changes to docker.io/jrcjoro1/mypythonapp1
Enter username: jrcjoro1
Enter password:
WARN[0033] Error getting targets/releases: valid signatures did not meet threshold for targets/releases
Enter passphrase for newsigner2 key with ID 950ec70:
Successfully published changes for repository docker.io/jrcjoro1/mypythonapp1
$
$ docker trust inspect --pretty jrcjoro1/mypythonapp1

Signatures for jrcjoro1/mypythonapp1

SIGNED TAG                                 DIGEST                                                             SIGNERS
59e4d39fb31b20be1ded800fe4e0a55492af47f6   e87e088c8b335b6cedf12d5cdd720c8900ea4d214fb0a1a8fb5ec8e90b8f51ba   (Repo Admin)
71e65392cd63a9673da21fdefa618772fdff25ee   e87e088c8b335b6cedf12d5cdd720c8900ea4d214fb0a1a8fb5ec8e90b8f51ba   (Repo Admin)
6954f2de0a2bc312b7e527cc7dd57afcad1e87ad   e87e088c8b335b6cedf12d5cdd720c8900ea4d214fb0a1a8fb5ec8e90b8f51ba   (Repo Admin)
d2c284704a2e6010c70cdff71cc34a3433a1083a   9171446e3dfba232cb70bbac39b69baa89cb28e24cc3ef0e53acc096f3f287b5   (Repo Admin)
f183e6894cae149b2670bdb32d14172affc8da1b   e87e088c8b335b6cedf12d5cdd720c8900ea4d214fb0a1a8fb5ec8e90b8f51ba   (Repo Admin)

List of signers and their keys for jrcjoro1/mypythonapp1

SIGNER       KEYS
jorosigner   1f3c4beb156f
newsigner2   950ec70deaca

Administrative keys for jrcjoro1/mypythonapp1

  Repository Key:       93b133c3b226bf5294b166c0bfd2d1f0193dfff42678cadb906e8c0bcc6969f8
  Root Key:     94a1795e22a745bc1dc3cb98a16bc78e861a2f4ae01deb7bfc58598461bdb2f7
```


### How to verify that container is signed

Signatures are stored in Notary server and Docker Hub supports all features of DCT. If you wan't to have private registry, you have to set up separate Notary service. In my Lab I use Docker Hub as a Notary service. 

When DCT is enabled with DOCKER_CONTENT_TRUST env variable, docker verify in pull that signatures exist. Below I have enabled DCT and try to pull container that does not have signatures:
```text
$ export DOCKER_CONTENT_TRUST=1
$
$ docker pull jrcjoro1/my-python-app:0.0.1
Error: remote trust data does not exist for docker.io/jrcjoro1/my-python-app: notary.docker.io does not have trust data for docker.io/jrcjoro1/my-python-app
```


### Backup all keys


Problems will arise if you loose keys, so keep them safe!


### Cleanup


In Lab environment idea is to play around and be able to start again at any point. With DCT this can be tricky, once keys have been created e.g. root key can not be replaced, so easiest way is to initiate new DCT repository and create all new keys for that. 




## CD Pipeline and signature verification in Kubernetes



### Connaisseur


Connaisseur is working with mutating webhooks:
```text
$  k get mutatingwebhookconfigurations -n test2
NAME                           WEBHOOKS   AGE
connaisseur-webhook            1          21m
vault-k8s-agent-injector-cfg   1          11m
$
$ k get mutatingwebhookconfigurations connaisseur-webhook -n test2 -o yaml
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  annotations:
    helm.sh/hook: post-install, post-upgrade, post-rollback
  creationTimestamp: "2024-03-20T12:40:12Z"
  generation: 1
  labels:
    app.kubernetes.io/component: connaisseur-webhook
    app.kubernetes.io/instance: connaisseur
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: connaisseur
    helm.sh/chart: connaisseur-2.3.4
  name: connaisseur-webhook
  resourceVersion: "912772"
  uid: 9de97d6e-4359-4a80-92bd-edf1d3ae236b
webhooks:
- admissionReviewVersions:
...
```


Export DCT root pub key for Connaisseur Helm chart:
```text
$ cd ~/.docker/trust/private/
$
$ grep 'role: root' *
7430b129956dd2a016d354eb555bf60908ea2fe37824d1420fb569131a9fd210.key:role: root
$
$ cd 
$
$ cp ~/.docker/trust/private/7430b129956dd2a016d354eb555bf60908ea2fe37824d1420fb569131a9fd210.key ./root-priv.key
$
$ sed -i -e '/^role:\sroot$/d' -e '/^$/d' root-priv.key
$
$ openssl ec -in root-priv.key -pubout -out root-pub.pem
read EC key
Enter pass phrase for root-priv.key:
writing EC key
$
$ cat root-pub.pem
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE3emk7zw/3/Io7U3uTFHc1QShztwx
i4kSpNTxNPhzMawCYz+Bm3QDDiG5SI3aa94C4p6r2/G8A++olF/voc3+IQ==
-----END PUBLIC KEY-----
```


Add Connaisseur Helm repo to system (role is in WSL2Fun git repository which is my Kube deployment home), for Ansible I set `REPONAME: connaisseur` and `REPOURL: "https://sse-secure-systems.github.io/connaisseur/charts"` variables in main.yml: 
```text
$ ansible-playbook main.yml --tags "helm-addrepo"
$
$ Verification of above Ansible in K8s:
$ helm repo list
NAME            URL
bitnami         https://charts.bitnami.com/bitnami
custom-repo     https://jouros.github.io/helm-repo
hashicorp       https://helm.releases.hashicorp.com
connaisseur     https://sse-secure-systems.github.io/connaisseur/charts
$
$ helm search repo -l connaisseur
NAME                    CHART VERSION   APP VERSION     DESCRIPTION
connaisseur/connaisseur 2.3.4           3.3.4           Helm chart for Connaisseur - a Kubernetes admis...
connaisseur/connaisseur 2.3.3           3.3.3           Helm chart for Connaisseur - a Kubernetes admis...
```


Next I'll deploy Connaisseur with Ansible (role in WSL2Fun repo) and check deployment from K8s:
```text
$ ansible-playbook main.yml --tags "helm-connaisseur"
ok: [kube1] =>
  msg: |-
    Release "connaisseur" does not exist. Installing it now.
    NAME: connaisseur
    LAST DEPLOYED: Fri Mar 15 13:07:39 2024
    NAMESPACE: connaisseur
    STATUS: deployed
    REVISION: 1
    TEST SUITE: None
$
$ k get pods -n connaisseur
NAME                                     READY   STATUS    RESTARTS   AGE
connaisseur-deployment-fb6df5669-b8ngn   1/1     Running   0          9m41s
connaisseur-deployment-fb6df5669-mbcfk   1/1     Running   0          9m41s
connaisseur-deployment-fb6df5669-w5gzb   1/1     Running   0          9m41s
```


Test Connaisseur deployment and signature validation with Securesystemsengineering signed and unsigned Pods:
```text
$ k run demo --image=docker.io/securesystemsengineering/testimage:signed
pod/demo created
$
$ k get pods
NAME   READY   STATUS    RESTARTS   AGE
demo   1/1     Running   0          25s
$
$ k run demo --image=docker.io/securesystemsengineering/testimage:unsigned
Error from server: admission webhook "connaisseur-svc.connaisseur.svc" denied the request: Unable to find signed digest for image docker.io/securesystemsengineering/testimage:unsigned.
```

As we can see, unsigned deployment failed. Lets test mypythonapp1:
```text
$ k run mypythonapp1 --image=docker.io/jrcjoro1/mypythonapp1:a1cc4decc0670cb8a0054e1649c0cb21bd4a7604 -n test2
pod/mypythonapp1 created

``` 


#### Vault setup for mypythonapp1


Settiing up Vault for mypythonapp1:
```text
$ K8s:
$ kubectl get secret vault-auth-secret -n test2  --output 'go-template={{ .data.token }}' | base64 --decode > JWT.crt
$
$ IaC host:
$ scp -3 -p k8s-admin@192.168.122.10:~/Mypythonapp/JWT.crt management@192.168.122.14:~/JWT.crt
$
$ Vault:
$
$ If it has been a while since talking to Vaulti, token will have timeout and I have renew it or I'll get 'permission deniend for mountpoint auth/kubernetes:
$ vault write auth/kubernetes/role/kubereadonlyrole bound_service_account_names=mypythonappsa bound_service_account_namespaces='*' policies=kubepolicy ttl=96h token_max_ttl=144h
Success! Data written to: auth/kubernetes/role/kubereadonlyrole
$
$ Next I'll check JWT and write config:
$ vault write auth/kubernetes/config kubernetes_host="https://kube1:6443" token_reviewer_jwt="$JWT" kubernetes_ca_cert="$KUBE_CA_CERT" disable_local_ca_jwt="true" issuer="kubernetes/serviceaccount" disable_iss_validation="true"
Success! Data written to: auth/kubernetes/config
$
$ vault read auth/kubernetes/config
Key                       Value
---                       -----
disable_iss_validation    true
disable_local_ca_jwt      true
issuer                    kubernetes/serviceaccount
```


#### Helm chart deployment for mypythonapp1


Next I'll pull new chart into K8s and do manual deployment test:
```text
$ helm repo update
Hang tight while we grab the latest from your chart repositories...
$
$ helm search repo -r 'mypythonapp1'
NAME                            CHART VERSION   APP VERSION     DESCRIPTION
custom-repo/mypythonapp1        0.0.1           0.0.1           A Helm chart for Kubernetes
$
$ helm pull custom-repo/mypythonapp1 --version 0.0.1 --untar
$
$ helm install mypythonapp1 ./mypythonapp1 --dry-run --namespace test2
$
$ helm install mypythonapp1 ./mypythonapp1 --namespace test2
NAME: mypythonapp1
LAST DEPLOYED: Tue Mar 19 15:32:10 2024
NAMESPACE: test2
STATUS: deployed
REVISION: 1
NOTES:
1. Get the application URL by running these commands:
  export POD_NAME=$(kubectl get pods --namespace test2 -l "app.kubernetes.io/name=mypythonapp1,app.kubernetes.io/instance=mypythonapp1" -o jsonpath="{.items[0].metadata.name}")
  export CONTAINER_PORT=$(kubectl get pod --namespace test2 $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
  echo "Visit http://127.0.0.1:8080 to use your application"
  kubectl --namespace test2 port-forward $POD_NAME 8080:$CONTAINER_PORT
```


Next I'll create new role for for automated Ansible deployments: 
```text
$ ansible-playbook main.yml --tags "helm-mypythonapp1"
$
$ k get pods -n test2
NAME                                        READY   STATUS    RESTARTS   AGE
mypythonapp1-77594795c6-sj94p               2/2     Running   0          7m45s
vault-k8s-agent-injector-779fdfc4f4-fsdtg   1/1     Running   0          42m
$
$ curl http://10.110.141.64:8080
{"data": {"password": "two", "username": "one"}, "metadata": {"created_time": "2024-02-15T12:16:15.948350293Z", "custom_metadata": null, "deletion_time": "", "destroyed": false, "version": 5}}
```

Mypythonapp1 is happily running :)



#### Debugging Connaisseur


```text
$ k logs deployment/connaisseur-deployment -n connaisseur | jq
```

Calico CNI is causing a lot of noise: 
```text
$ k logs deployment/connaisseur-deployment -n connaisseur | jq | grep 'verific'
Found 3 pods, using pod/connaisseur-deployment-65f9f9fc7f-4qg4n
  "message": "starting verification of image \"docker.io/calico/typha:v3.26.4\" using rule \"docker.io/calico/*\" with arguments {} and validator \"allow\".",
  "message": "successful verification of image \"docker.io/calico/typha:v3.26.4\"",
  "message": "starting verification of image \"docker.io/calico/node:v3.26.4\" using rule \"docker.io/calico/*\" with arguments {} and validator \"allow\".",
  "message": "successful verification of image \"docker.io/calico/node:v3.26.4\"",
  "message": "starting verification of image \"docker.io/calico/pod2daemon-flexvol:v3.26.4\" using rule \"docker.io/calico/*\" with arguments {} and validator \"allow\".",
  "message": "successful verification of image \"docker.io/calico/pod2daemon-flexvol:v3.26.4\"",
```


### Helm chart creation in CI pipeline


First I'll add my custom-repo to Runner:
```text
$ helm repo add custom-repo https://jouros.github.io/helm-repo
"custom-repo" has been added to your repositories
$
$ helm search repo -r 'mypythonapp1'
NAME                            CHART VERSION   APP VERSION     DESCRIPTION
custom-repo/mypythonapp1        0.0.1           0.0.1           A Helm chart for Kubernetes
$

```

I'll use above repo just to pull my latest chart version to Runner and make that chart template for CI pipeline. 


I use very simple bash + sed combination to set variables into build based Chart:
```text
$ cat ~/bin/edit_chart.sh
#!/bin/bash

chartVersion=$1
imageTag=$2
imageName=$3
userName=$4
BuildSourceVersion=$5

echo "parameters from pipeline: '$1' '$2'  '$3' '$4' '$5'"


cp -r /home/agentuser/helm_template/charts/mypythonapp1 "/home/agentuser/helm_template/charts/$BuildSourceVersion"

sed -i "s/^\(version:\).*/\1 $chartVersion/" "/home/agentuser/helm_template/charts/$BuildSourceVersion/Chart.yaml"
sed -i "s/^\(appVersion:\).*/\1 $imageTag/" "/home/agentuser/helm_template/charts/$BuildSourceVersion/Chart.yaml"
sed -i "s/^\(name:\).*/\1 $imageName/" "/home/agentuser/helm_template/charts/$BuildSourceVersion/Chart.yaml"
sed -i "s/\(tag:\).*/\1 \"$BuildSourceVersion\"/" "/home/agentuser/helm_template/charts/$BuildSourceVersion/values.yaml"
sed -i "s/\(repository:\).*/\1 $userName\/$imageName/" "/home/agentuser/helm_template/charts/$BuildSourceVersion/values.yaml"
```


Charts are also stored locally in Runner

Dockerhub is OCI compatible so I can store Helm charts into registry:
```text
$ helm pull oci://registry-1.docker.io/jrcjoro1/mypythonapp1 --version 0.0.2
Pulled: registry-1.docker.io/jrcjoro1/mypythonapp1:0.0.2
Digest: sha256:41532be97d0cd5cb238b996579174f0010712a4b8ca5834801325f94a0646410
```


### CD automation with Flux 


#### Flux deployment with Ansible


For Flux deployment I have main-flux.yml + required roles in WSL2FUN repo:
```text
$ ansible-playbook main-flux.yml --tags "download-flux"
$
$ ansible-playbook main-flux.yml --tags "deploy-flux"
$
$ ansible-playbook main-flux.yml --tags "precheck-flux"
ok: [kube1] =>
  msg:
  - ► checking prerequisites
  - ✔ Kubernetes 1.28.2 >=1.26.0-0
  - ✔ prerequisites checks passed
```



```text
$ ansible-playbook main-flux.yml --tags "bootstrap-flux"
ok: [kube1] =>
  msg:
    changed: true
    cmd: |-
      flux bootstrap github --owner=jouros --repository=FluxKube1 --branch=main --path=clusters/kube1 --personal --private --timeout=2m0s --verbose
...
```

```text
$ tree
.
└── clusters
    └── kube1
        └── flux-system
            ├── gotk-components.yaml
            ├── gotk-sync.yaml
            └── kustomization.yaml
```

```text
$ k get pods -n flux-system
NAME                                       READY   STATUS    RESTARTS   AGE
helm-controller-5d8d5fc6fd-cc2t5           1/1     Running   0          3h2m
kustomize-controller-7b7b47f459-6wprr      1/1     Running   0          3h2m
notification-controller-5bb6647999-qb28t   1/1     Running   0          3h2m
source-controller-7667765cd7-m59t8         1/1     Running   0          3h2m
```

#### Flux git setup


Flux setup in git:
```text
$ tree
.
├── clusters
│   └── kube1
│       ├── flux-system
│       │   ├── gotk-components.yaml
│       │   ├── gotk-sync.yaml
│       │   └── kustomization.yaml
│       └── tenants.yaml
└── tenants
    ├── base
    │   └── mypythonapp1
    │       ├── kustomization.yaml
    │       ├── rbac.yaml
    │       └── sync.yaml
    └── kube1
        └── kustomization.yaml
```



Flux cluster tenants: clusters/kube1/tenants.yaml
```text
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: tenants
  namespace: flux-system
spec:
  interval: 5m
  serviceAccountName: kustomize-controller
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./tenants/kube1
  prune: true
```

Tenant Kustomization: tenants/kube1/kustomization.yaml
```text
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../base/mypythonapp1
```

Flux RBAC: tenants/base/mypythonapp1/rbac.yaml
```text
---
apiVersion: v1
kind: Namespace
metadata:
  labels:
    toolkit.fluxcd.io/tenant: kube1
  name: test2
---
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    toolkit.fluxcd.io/tenant: kube1
  name: kube1
  namespace: test2
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    toolkit.fluxcd.io/tenant: kube1
  name: gotk-reconciler
  namespace: test2
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: gotk:test2:reconciler
- kind: ServiceAccount
  name: kube1
  namespace: test2
```


Flux OCI config: tenants/base/mypythonapp1/sync.yaml
```text
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: mypythonapp1
  namespace: test2
spec:
  interval: 1m0s
  type: oci
  url: oci://docker.io/jrcjoro1 #
  secretRef:
    name: fluxregcred
---
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: mypythonapp1
  namespace: test2
spec:
  interval: 1m0s
  timeout: 2m
  chart:
    spec:
      chart: mypythonapp1
      reconcileStrategy: ChartVersion
      version: '0.*.*'
      sourceRef:
        kind: HelmRepository
        name: mypythonapp1
      interval: 1m0s
  releaseName: mypythonapp1
  serviceAccountName: kube1
  install:
    remediation:
      retries: 3
  upgrade:
    remediation:
      retries: 3
  test:
    enable: false
```


I added new SA 'kube1' into Vault config, beacuse mypythonapp1 need Vault connection for start:
```text
$ vault write auth/kubernetes/role/kubereadonlyrole bound_service_account_names='mypythonappsa,kube1' bound_service_account_namespaces='*' policies=kubepolicy ttl=96h token_max_ttl=144h
Success! Data written to: auth/kubernetes/role/kubereadonlyrole
$
$ vault read auth/kubernetes/role/kubereadonlyrole
...
bound_service_account_names         [mypythonappsa kube1]
```

Preparing state:
```text
$ k get pods -n test2
NAME                                        READY   STATUS            RESTARTS       AGE
mypythonapp1-6866d989dd-k9bjm               0/2     PodInitializing   0              4m31s
vault-k8s-agent-injector-779fdfc4f4-fsdtg   1/1     Running           62 (24m ago)   28d
```

Final stage:
```text
$ k get pods -n test2
NAME                                        READY   STATUS    RESTARTS       AGE
mypythonapp1-6866d989dd-k9bjm               2/2     Running   0              4m35s
vault-k8s-agent-injector-779fdfc4f4-fsdtg   1/1     Running   62 (24m ago)   28d
```

Final stage from Flux:
```text
$ flux get sources all -A
NAMESPACE       NAME                            REVISION                SUSPENDED       READY   MESSAGE
flux-system     gitrepository/flux-system       main@sha1:e2b6b998      False           True    stored artifact for revision 'main@sha1:e2b6b998'

NAMESPACE       NAME                            REVISION        SUSPENDED       READY   MESSAGE
test2           helmrepository/mypythonapp1                     False           True    Helm repository is Ready

NAMESPACE       NAME                            REVISION        SUSPENDED       READY   MESSAGE
test2           helmchart/test2-mypythonapp1    0.0.3           False           True    pulled 'mypythonapp1' chart with version '0.0.3'
```

In my previous deployments I have used different SA and I changed my Chart template to have this new 'kube1' SA for this Flux CI/CD deplolyment. 











