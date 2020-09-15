![](https://img.shields.io/badge/Stability-Experimental-red.svg)

This repository is [Experimental](https://github.com/packethost/standards/blob/master/experimental-statement.md) meaning that it's based on untested ideas or techniques and not yet established or finalized or involves a radically new and innovative style! This means that support is best effort (at best!) and we strongly encourage you to NOT use this in production.

# Kata on Packet

Wouldn't it be nice if you could use `kata` under `minikube` to get an easy out of the box experience to try out Kata?

Here is how to use a Packet bare metal host to run `kvm` via `minikube`, and then utilise nested virtualisation
to get `kata` VMs to run under `minikube`.

# Software Components

[minikube](https://kubernetes.io/docs/setup/minikube/) provides the virtualization to run a single node Kubernetes stack in a local VM.

[Kata Containers](https://github.com/kata-containers) is an OCI compatible container runtime that runs container workloads inside VMs.

## Prerequisites

* Terraform - See [Terraform Download](https://www.terraform.io/downloads.html)
* Git - See [Git](https://git-scm.com/downloads)
* Packet Account - See [Packet Signup](https://app.packet.net/signup)
* Packet Project ID & API User Token - See [Packet API FAQ](https://support.packet.com/kb/articles/api-integrations)

## Download Repo

Download this code locally 
```
git clone https://github.com/packet-labs/Kata-on-Packet
cd Kata-on-Packet/terraform
```

## Setup Packet Account Details

Replace the following with your own API Auth Token and Project ID values from the Packet GUI and then execute to update the config.
```
cp terraform.tfvars.sample terraform.tfvars
echo packet_auth_token=\"ABCDEFGHIJKLMNOPQRSTUVWXYZ123456\" >> terraform.tfvars
echo packet_project_id=\"12345678-90AB-CDEF-GHIJ-KLMNOPQRSTUV\" >> terraform.tfvars
```

## Deploy Lab Host

Apply the Terraform which will startup a new physical host and install all the required software.
```
terraform init
terraform apply
```

## Log into the Lab

List the IP address of the lab.
```
terraform output
```

Log into the new host using an SSH client with the username lab.
```
ssh lab@<Lab IP>
```
The default password for the lab user is openstack.


## Setting up `minikube`

To enable `kata` under `minikube`, we need to add a few configuration options to the default `minikube` setup. This is nice
and easy, as `minikube` supports them on the setup commandline.

Here are the features, and why we need them:

| what | why |
| ---- | --- |
| --vm-driver kvm2 | The host VM driver I tested with |
| --memory 6144 | Allocate more memory, as Kata containers default to 1 or 2Gb |
| --feature-gates=RuntimeClass=true | Kata needs to use the RuntimeClass k8s feature |
| --network-plugin=cni | As recommended for [minikube CRI-o](https://kubernetes.io/docs/setup/minikube/#cri-o) |
| --enable-default-cni | As recommended for [minikube CRI-o](https://kubernetes.io/docs/setup/minikube/#cri-o) |
| --container-runtime=cri-o | Using CRI-O for Kata |
| --bootstrapper=kubeadm | As recommended for [minikube CRI-o](https://kubernetes.io/docs/setup/minikube/#cri-o) |

for `minikube` specific installation instructions see [the docs](https://kubernetes.io/docs/tasks/tools/install-minikube/),
which will also help locate the information needed to get the `kvm2` driver installed etc.

Here then is the command I ran to get my basic `minikube` set up ready to add `kata`:

```bash
minikube start \
 --vm-driver kvm2 \
 --memory 6144 \
 --feature-gates=RuntimeClass=true \
 --network-plugin=cni \
 --enable-default-cni \
 --container-runtime=cri-o \
 --bootstrapper=kubeadm
```

That command will take a little while to pull down and install items, but ultimately should complete successfully.

## Checking for nested virtualisation

Your `minikube` should now be up. Let's try a quick check:

```bash
lab@lab00$ kubectl get nodes
NAME       STATUS   ROLES    AGE   VERSION
minikube   Ready    master   78m   v1.13.4
```

Now let's check if you have nested virtualisation enabled inside the `minikube` node:

```bash
lab@lab00$ minikube ssh
                         _             _            
            _         _ ( )           ( )           
  ___ ___  (_)  ___  (_)| |/')  _   _ | |_      __  
/' _ ` _ `\| |/' _ `\| || , <  ( ) ( )| '_`\  /'__`\
| ( ) ( ) || || ( ) || || |\`\ | (_) || |_) )(  ___/
(_) (_) (_)(_)(_) (_)(_)(_) (_)`\___/'(_,__/'`\____)

# No color option, as minikube is running busybox
$ egrep 'vmx|svm' /proc/cpuinfo
# if you get a long line of output here, you have it enabled!

$ exit
```

## Installing `kata`

Now we need to install the `kata` runtime components. Terraform has already downloaded the `kata` components to help with this.
Use the host `kubectl` to deploy them:

```bash
lab@lab00$ kubectl apply -f packaging/kata-deploy/kata-rbac.yaml
lab@lab00$ kubectl apply -f packaging/kata-deploy/kata-deploy.yaml
```
This should have installed the `kata` components into `/opt/kata` inside the `minikube` node. Let's check:

```bash
lab@lab00$ minikube ssh
$ cd /opt/kata
$ ls bin
containerd-shim-kata-v2  kata-fc       qemu-ga             virtfs-proxy-helper
firecracker              kata-qemu     qemu-pr-helper
kata-collect-data.sh     kata-runtime  qemu-system-x86_64
$ exit
```

And there we can see the `kata` components, including a `qemu`, and the `kata-runtime` for instance.

## Enabling `kata`

Now the `kata` components are installed in the `minikube` node, we need to configure `k8s` `RuntimeClass` so it knows how
and when to use `kata` to run a pod.

```bash
lab@lab00$ curl https://raw.githubusercontent.com/kubernetes/node-api/master/manifests/runtimeclass_crd.yaml > runtimeclass_crd.yaml
lab@lab00$ kubectl apply -f runtimeclass_crd.yaml
```

And now we need to register the `kata qemu` runtime with that class:

```bash
# A temporary workaround until the scripts land in the packaging/kata-deploy repo
$ git clone https://github.com/clearlinux/cloud-native-setup.git
$ cd cloud-native-setup/clr-k8s-examples
$ kubectl apply -f 8-kata/kata-qemu-runtimeClass.yaml
# Note, there is also a kata-fc-runtimeClass.yaml that will enable 'firecracker with kata' support
# enabling and testing that is left as 'an exercise for the user'
```

`kata` should now be installed and enabled in the `minikube` cluster. Time to test it...

## Testing `kata`

OK, time to see if all that worked. First, let's launch a container that is defined to run on Kata. For reference,
the magic lines in the yaml are:

```yaml
    spec:
      runtimeClassName: kata-qemu
```

```bash
lab@lab00$ kubectl apply -f packaging/kata-deploy/examples/test-deploy-kata-qemu.yaml
```

This deploys an apache php container run with the `kata` runtime. Wait a few moments to check it is running:

```bash
$ kubectl get pods
NAME                                   READY   STATUS    RESTARTS   AGE
php-apache-kata-qemu-bc4c55994-p6f6k   1/1     Running   0          1m
```

And then there are a couple of ways to verify it is running with Kata. Nominally, it should be hard to tell - the idea of
`kata` is that your container will run inside a VM, but look and feel just like it would as a normal software container. In
theory, if you can tell the difference then there are things still to improve ;-).

First, we'll have a look on the node:

```bash
$ minikube ssh
$ ps -ef | fgrep qemu-system
# VERY long line of qemu here - showing that we are indeed running a qemu VM on the minikube node - that is the VM that contains
# your pod.
#
# And for refernce in a moment, let's see what kernel is running on the node itself
$ uname -a
Linux minikube 4.15.0 #1 SMP Wed Mar 6 23:18:58 UTC 2019 x86_64 GNU/Linux
$ exit
```

OK, so hopefully we saw a `qemu` process running, indicating that we did have a `kata` container up. Now, another way to verify
that is to hop into the container itself and have a look at what kernel is running there. For a normal software container you
will be running the same kernel as the node, but for a `kata` container you will be running a `kata` kernel inside the `kata` VM.

```bash
$ kubectl get pods
NAME                                   READY   STATUS    RESTARTS   AGE
php-apache-kata-qemu-bc4c55994-p6f6k   1/1     Running   0          2m
$ kubectl exec -ti php-apache-kata-qemu-bc4c55994-p6f6k bash
# Am now in the container...
root@php-apache-kata-qemu-bc4c55994-p6f6k:/var/www/html# uname -a
Linux php-apache-kata-qemu-bc4c55994-p6f6k 4.19.24 #1 SMP Mon Mar 4 13:40:48 CST 2019 x86_64 GNU/Linux
# exit
```

And, there we can see, the node is running kernel 4.15, but the container running under `kata` is running a 4.19 kernel.

## Wrapping up

So, there we have it. A relatively easy way to get a `minikube` up with `kata` containers installed. Be aware, this is only a
small single node k8s cluster running under a nested virtualisation setup, so it will have limitaions - but, as a first introduction
to `kata`, and how to install it under kubernetes, it does its job.



