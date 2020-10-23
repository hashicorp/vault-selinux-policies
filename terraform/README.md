# quick ec2

A quick terraform to spin up instances in aws to test Vault SELinux policies on.

By default this will spin up a CentOS and Fedora instance.

## Prerequisites

Will expect ~/.ssh/id_rsa.pub to exist by default.

You also need to have AWS credentials / config setup in your ~/.aws/ folder.

Oh, and terraform (tested with version 0.12.21). 

## Config

If you want to modify the 'name' or 'ssh pub key' for terraform feel free to set variables for `name` and `pub_key_file` in setup.auto.tfvars.

Variables:
* **name** : Used as a prefix and other name for TF resources (default: test)
* **pub_key_file** : File location of the SSH public key bootstrapped onto the instance. (default: ~/.ssh/id_rsa.pub)
* **region** : The AWS region to spin up resources (default: us-east-1)

## Spinning up / refreshing

```bash
$ make up
```

## Spinning down

```bash
$ make down
```

## Accessing server

```bash
$ terraform output
$ ssh -i ~/.ssh/id_rsa ubuntu@ip
```

Sometimes the user-data.sh may take a while, you can check it's complete by running the following on the instance.

```bash
$ cloud-init status --wait
```
