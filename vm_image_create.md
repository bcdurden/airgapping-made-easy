# Prep Harvester's Ubuntu OS Image
To make this special image, we'll need to pull down the previously mentioned OS image to our local workstation and then do some work upon it using `guestfs` tools. This is slightly involved, but once finished, you'll have 80% of the manual steps above canned into a single image making it very easy to automate in an airgap. If you are not using Harvester, this image is in qcow2 format and should be usable in different HCI solutions, however your Terraform code will look different. Try to follow along, regardless, so the process around how you would bootstrap the cluster (and Rancher) from Terraform is understood at a high-level.

```bash
wget http://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img
sudo apt install -y libguestfs-tools
```

Before we get started, we'll need to expand the filesystem of the cloud image because some of the files we are downloading are a little large. I'm using 3 gigs here, but if you're going to install something large like nvidia-drivers, use as much space as you like. We'll condense the image back down later.
```bash
sudo virt-filesystems --long -h --all -a ubuntu-20.04-server-cloudimg-amd64.img
truncate -r ubuntu-20.04-server-cloudimg-amd64.img ubuntu-rke2.img
truncate -s +3G ubuntu-rke2.img
sudo virt-resize --expand /dev/sda1 ubuntu-20.04-server-cloudimg-amd64.img ubuntu-rke2.img

```

Unfortunately `virt-resize` will also rename the partitions, which will screw up the bootloader. We now have to fix that by using virt-rescue and calling grub-install on the disk.

Start the `virt-rescue` app like this:
```bash
sudo virt-rescue ubuntu-rke2.img 
```

And then paste these commands in after the rescue app finishes starting:
```bash
mkdir /mnt
mount /dev/sda3 /mnt
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys
chroot /mnt
grub-install /dev/sda
```

After that you can exit hitting `ctrl ]` and then hitting `q`.
```console
sudo virt-rescue ubuntu-rke2.img 
WARNING: Image format was not specified for '/home/ubuntu/ubuntu-rke2.img' and probing guessed raw.
         Automatically detecting the format is dangerous for raw images, write operations on block 0 will be restricted.
         Specify the 'raw' format explicitly to remove the restrictions.
Could not access KVM kernel module: No such file or directory
qemu-system-x86_64: failed to initialize KVM: No such file or directory
qemu-system-x86_64: Back to tcg accelerator
supermin: mounting /proc
supermin: ext2 mini initrd starting up: 5.1.20
...

The virt-rescue escape key is ‘^]’.  Type ‘^] h’ for help.

------------------------------------------------------------

Welcome to virt-rescue, the libguestfs rescue shell.

Note: The contents of / (root) are the rescue appliance.
You have to mount the guest’s partitions under /sysroot
before you can examine them.

groups: cannot find name for group ID 0
><rescue> mkdir /mnt
><rescue> mount /dev/sda3 /mnt
><rescue> mount --bind /dev /mnt/dev
><rescue> mount --bind /proc /mnt/proc
><rescue> mount --bind /sys /mnt/sys
><rescue> chroot /mnt
><rescue> grub-install /dev/sda
Installing for i386-pc platform.
Installation finished. No error reported.
```

Now we can inject both packages as well as run commands within the context of the image. We'll borrow some of the manual provisioning steps above and copy those pieces into the image. The run-command will do much of what our `pull_rke2` script was doing but focused around pulling binaries and install scripts. We will create the configurations for these items using cloud-init in later steps.

```bash
sudo virt-customize -a ubuntu-rke2.img --install qemu-guest-agent
sudo virt-customize -a ubuntu-rke2.img --run-command "mkdir -p /var/lib/rancher/rke2-artifacts && wget https://get.rke2.io -O /var/lib/rancher/install.sh && chmod +x /var/lib/rancher/install.sh"
sudo virt-customize -a ubuntu-rke2.img --run-command "wget https://kube-vip.io/k3s -O /var/lib/rancher/kube-vip-k3s && chmod +x /var/lib/rancher/kube-vip-k3s"
sudo virt-customize -a ubuntu-rke2.img --run-command "mkdir -p /var/lib/rancher/rke2/server/manifests && wget https://kube-vip.io/manifests/rbac.yaml -O /var/lib/rancher/rke2/server/manifests/kube-vip-rbac.yaml"
sudo virt-customize -a ubuntu-rke2.img --run-command "cd /var/lib/rancher/rke2-artifacts && curl -sLO https://github.com/rancher/rke2/releases/download/v1.24.8+rke2r1/rke2.linux-amd64.tar.gz"
sudo virt-customize -a ubuntu-rke2.img --run-command "cd /var/lib/rancher/rke2-artifacts && curl -sLO https://github.com/rancher/rke2/releases/download/v1.24.8+rke2r1/sha256sum-amd64.txt"
sudo virt-customize -a ubuntu-rke2.img --run-command "cd /var/lib/rancher/rke2-artifacts && curl -sLO https://github.com/rancher/rke2/releases/download/v1.24.8+rke2r1/rke2-images.linux-amd64.tar.zst"
sudo virt-customize -a ubuntu-rke2.img --run-command "echo -n > /etc/machine-id"
```

If we look at the image we just created, we can see it is quite large!
```console
ubuntu@jumpbox:~$ ll ubuntu*
-rw-rw-r-- 1 ubuntu ubuntu  637927424 Dec 13 22:16 ubuntu-20.04-server-cloudimg-amd64.img
-rw-rw-r-- 1 ubuntu ubuntu 3221225472 Dec 19 14:40 ubuntu-rke2.img
```

We need to shrink it back using virt-sparsify. This looks for any unused space (most of what we expanded) and then removes that from the physical image. Along the way we'll want to convert and then compress this image:
```bash
sudo virt-sparsify --convert qcow2 --compress ubuntu-rke2.img ubuntu-rke2-airgap-harvester.img
```

Example of our current image and cutting the size in half:
```console
ubuntu@jumpbox:~$ sudo virt-sparsify --convert qcow2 --compress ubuntu-rke2.img ubuntu-rke2-airgap-harvester.img
[   0.0] Create overlay file in /tmp to protect source disk
[   0.0] Examine source disk
 100% ⟦▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒⟧ --:--
[  14.4] Fill free space in /dev/sda2 with zero
 100% ⟦▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒⟧ --:--
[  17.5] Fill free space in /dev/sda3 with zero
 100% ⟦▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒⟧ 00:00
[  21.8] Copy to destination and make sparse
[ 118.8] Sparsify operation completed with no errors.
virt-sparsify: Before deleting the old disk, carefully check that the 
target disk boots and works correctly.
ubuntu@jumpbox:~$ ll ubuntu*
-rw-rw-r-- 1 ubuntu ubuntu  637927424 Dec 13 22:16 ubuntu-20.04-server-cloudimg-amd64.img
-rw-r--r-- 1 root   root   1562816512 Dec 19 15:00 ubuntu-rke2-airgap-harvester.img
-rw-rw-r-- 1 ubuntu ubuntu 3221225472 Dec 19 14:40 ubuntu-rke2.img
```

What we have now is a customized image named `ubuntu-rke2-airgap-harvester.img` containing the RKE2 binaries and install scripts that we can later invoke in cloud-init. Let's upload this to Harvester now. The easiest way to upload into Harvester is host the image somewhere so Harvester can pull it. If you want to manually upload it from your web session, you stand the risk of it being interrupted by your web browser and having to start over.

Since my VM is hosted in my same harvester instance, I'm going to use a simple `python3` fileserver in my workspace directory:
```bash
python3 -m http.server 9900
```

See it running here:
```console
ubuntu@jumpbox:~$ python3 -m http.server 9900
Serving HTTP on 0.0.0.0 port 9900 (http://0.0.0.0:9900/) ...
```

From my web browser I can visit this URL at http://<my_jumpbox_ip>:9900 and 'copy link' on the `ubuntu-rke2-airgap-harvester.img` file.

![filehost](images/filehost.png)

And then create a new Harvester image and paste the URL into the field. The file should download quickly here as the VM is co-located on the Harvester box so it is effectively a local network copy.

![filehost](images/createimage.png)
![images](images/images.png)

Now using the earlier steps in the manual provivisoning, we can create a test VM to ensure the image is good to go. We can alter our cloud-init now as we don't need any new packages or package updates, the qemu agent just needs to be enabled so the IP reports correctly. My key hash is injected automatically but I removed the package update and install commands.
```yaml
#cloud-config
runcmd:
  - - systemctl
    - enable
    - --now
    - qemu-guest-agent.service
ssh_authorized_keys:
  - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDZk5zkAj2wbSs1r/AesCC7t6CtF6yxmCjlXgzqODZOujVscV6PZzIti78dIhv3Yqtii/baFH0PfqoHZk9eayjZMcp+K+6bi4lSwszzDhV3aGLosPRNOBV4uT+RToEmiXwPtu5rJSRAyePu0hdbuOdkaf0rGjyUoMbqJyGuVIO3yx/+zAuS8hFGeV/rM2QEhzPA4QiR40OAW9ZDyyTVDU0UEhwUNQESh+ZM2X9fe5VIxNZcydw1KGwzj8t+6WuYBFvPKYR5sylAnocBWzAGKh+zHgZU5O5TwC1E92uPgUWNwMoFdyZRaid0sKx3O3EqeIJZSqlfoFhz3Izco+QIx4iqXU9jIVFtnTb9nCN/boXx7uhCfdaJ0WdWQEQx+FX092qE6lfZFiaUhZI+zXvTeENqVfcGJSXDhDqDx0rbbpvXapa40XZS/gk0KTny2kYXBATsUwZqmPpZF9njJ+1Hj/KSNhFQx1LcIQVvXP+Ie8z8MQleaTTD0V9+Zkw2RBkVPYc5Vb8m8XCy1xf4DoP6Bmb4g3iXS17hYQEKj1bfBMbDfZdexbSPVOUPXUMR2aMxz8R3OaswPimLmo0uPiyYtyVQCuJu62yrao33knVciV/xlifFsqrNDgribDNr4RKnrIX2eyszCiSv2DoZ6VeAhg8i6v6yYL7RhQM31CxYjnZK4Q==
```

I'll not show the other images here, but show the SSH output of the started VM:
```console
> ssh -i ~/.ssh/harvester_test ubuntu@10.10.5.77
The authenticity of host '10.10.5.77 (10.10.5.77)' can't be established.
ED25519 key fingerprint is SHA256:5EhVyhModCMWMtI0zcd+dErCDnjVGlkmI/8CDuHOJ2g.
This key is not known by any other names
...
Ubuntu comes with ABSOLUTELY NO WARRANTY, to the extent permitted by
applicable law.

To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

ubuntu@test-image:~$ ll /var/lib/rancher
total 44
drwxr-xr-x  4 root root  4096 Dec 19 14:37 ./
drwxr-xr-x 41 root root  4096 Dec 19 15:18 ../
-rwxr-xr-x  1 root root 22291 Dec 19 14:36 install.sh*
-rwxr-xr-x  1 root root  1397 Dec 19 14:36 kube-vip-k3s*
drwxr-xr-x  3 root root  4096 Dec 19 14:37 rke2/
drwxr-xr-x  2 root root  4096 Dec 19 14:38 rke2-artifacts/
ubuntu@test-image:~$ ll /var/lib/rancher/rke2-artifacts/
total 840560
drwxr-xr-x 2 root root      4096 Dec 19 14:38 ./
drwxr-xr-x 4 root root      4096 Dec 19 14:37 ../
-rw-r--r-- 1 root root 812363060 Dec 19 14:40 rke2-images.linux-amd64.tar.zst
-rw-r--r-- 1 root root  48350150 Dec 19 14:37 rke2.linux-amd64.tar.gz
-rw-r--r-- 1 root root      3626 Dec 19 14:38 sha256sum-amd64.txt
ubuntu@test-image:~$ ll /var/lib/rancher/rke2/server/manifests/
total 12
drwxr-xr-x 2 root root 4096 Dec 19 14:37 ./
drwxr-xr-x 3 root root 4096 Dec 19 14:37 ../
-rw-r--r-- 1 root root  805 Dec 19 14:37 kube-vip-rbac.yaml
```

We can see here that all the files I copied in are now present and ready! We can copy this image to physical media along with our container images and use it as a prepped RKE2 node image. When using it, we only need to tweak the cloud-init to create/join a cluster with a certain config!