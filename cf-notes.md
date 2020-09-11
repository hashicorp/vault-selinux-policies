# How I got this going

Random notes

Spun up a a Centos AMI (using un-committed stuff in github.com/hashicorp/security-tools/tf-random/quick-ec2)

```
data "aws_ami" "centos" {
  owners      = ["679593333241"]
  most_recent = true

  filter {
      name   = "name"
      values = ["CentOS Linux 7 x86_64 HVM EBS *"]
  }

  filter {
      name   = "architecture"
      values = ["x86_64"]
  }

  filter {
      name   = "root-device-type"
      values = ["ebs"]
  }
}

resource "aws_instance" "instance" {
  ami = data.aws_ami.centos.id
  instance_type = "t2.medium"
  key_name = aws_key_pair.ssh.key_name
  subnet_id = aws_subnet.public.id
  vpc_security_group_ids = ["${aws_security_group.ssh.id}"]
  user_data = data.template_file.user_data.rendered
}
```

Created /opt/vault
Created /etc/vault.d/vault.hcl

```
storage "raft" {
  path = "/opt/vault/data"
  node_id = "node-1"
}

cluster_addr = "http://127.0.0.1:8201"
api_addr = "http://0.0.0.0:8200"

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = "true"
}
```

Created /etc/systemd/system/vault.service

```
[Unit]
Description="HashiCorp Vault - A tool for managing secrets"
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault.d/vault.hcl
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitInterval=60
StartLimitIntervalSec=60
StartLimitBurst=3
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
```

`sudo yum -y install wget unzip tmux policycoreutils-devel setools-console`

Put vault binary in /usr/bin/vault (although I should mimic httpd)

```
[root@ip-10-38-1-171 ~]# ls -alZ /sbin/httpd
-rwxr-xr-x. root root system_u:object_r:httpd_exec_t:s0 /sbin/httpd
```

Then started playing with `sepolicy generate --init -n vault /usr/bin/vault`

But then I think I screwed up - in that I accidentally permitted _too_ much stuff before I'd set the file permissions. Instead I should mark all the filesystem labels _first_. And _then_ run `sh ./vault.sh`

To add the labels for filesystem access, I added the following up the top of my `vault.te`

```
type vault_conf_t;
files_type(vault_conf_t)
type vault_sys_content_t;
files_type(vault_sys_content_t)
```

Omg - and clone https://github.com/SELinuxProject/refpolicy - this has all the macro source.
AND
https://github.com/fedora-selinux/selinux-policy

After installing package - but not running vault

```
chcon -u system_u -t vault_conf_t -R /etc/vault.d
chcon -u system_u -t vault_sys_content_t -R /opt/vault
```

Don't forget to create Vault user
```
useradd --system --home-dir /etc/vault.d --shell /bin/false vault
```

Source for `init_nnp_daemon_domain(vault_t)` from https://src.fedoraproject.org/rpms/selinux-policy/c/107eb82b3e182d72c7f2c7f8f03bda6dd790f441?branch=master

```
+########################################            
                    +            +## <summary>            
                    +            +##    Allow SELinux Domain trasition from sytemd            
                    +            +##  into confined domain with NoNewPrivileges             
                    +            +##  Systemd Security feature.            
                    +            +## </summary>            
                    +            +## <param name="domain">            
                    +            +##    <summary>            
                    +            +##    Domain allowed access.            
                    +            +##    </summary>            
                    +            +## </param>            
                    +            +#            
                    +            +interface(`init_nnp_daemon_domain',`            
                    +            +    gen_require(`            
                    +            +        type init_t;            
                    +            +    ')            
                    +            +            
                    +            +    allow init_t $1:process2 { nnp_transition nosuid_transition };            
                    +            +')            
                    +
```

needed to make /opt/vault vault:vault

If you can't see exceptions - they may be muted by `dontaudit` - as per https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/using_selinux/troubleshooting-problems-related-to-selinux_using-selinux you can see dontaudits by

```
semodule -DB
```

To turn this back
```
semodule -B
```

the rpm package stuff is a bit confusing, but I referred to stuff in https://blog.packagecloud.io/eng/15/04/20/working-with-source-rpms/

Then don't forget

```
vault audit enable file file_path=/var/log/vault/vault.log
```
