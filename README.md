---
title: Airgapping made easy with RKE2 and Rancher
author: Brian Durden
---
# Airgapping made easy with RKE2 and Rancher

## TL;DR
You're here and you want to go REAL fast? There's a couple things you'll need to ensure are setup before you're done. All of that is defined here and within the [manual install doc](./manual_install.md). If you're wanting to dive in a bit deeper into some concepts around Airgapping, continue reading!

* All Rancher images are in your internal registry already (scripts are provided here to help you with this, see the [manual install doc](./manual_install.md))
* VM image has been created and is fetchable from a URL, see the [vm creation doc](./vm_image_create.md)
* Create a `terraform.tfvars` file from the [terraform.tfvars.example template](terraform/terraform.tfvars.example) and fill out the values inside
* Prep your terraform directory using `terraform init` and verify all variables are set using `terraform plan`
* Migrate this directory tree into your airgap if necessary so you have all the terraform code there

Once those steps are complete, you can just run `terraform apply` within the `terraform/` directory! Jump to the bottom to see what the output of that looks like.

## Use Case and Scope
There are a few use cases addressed here, but each bears some early discussion. This document will cover provisioning and bootstrapping a Rancher Cluster Manager with RKE2 in a manual way and in a more declarative way using Terraform. Both cases will cover a soft-airgap scenario where internal networks do not have or should not have access to the internet or external networks as a general rule. While some cases to exist where a soft-airgap can make use of a whitelist of domains/IPs, we'll assume that doesn't exist in this case.

Given this airgap need, we'll need to have everything that is normally pulled or used in the public cloud available within our private environment. This covers everything from container images, code, scripts, and config files. Because of this, airgapping can involve a significant amount of toil for basic use-cases making it difficult and time-consuming to keep the system up to date and patched. This doc will cover all of that work as well as provide some helpful tools to make this process as easy as possible.

There may be questions why we are not going to automatically stand up a temporary Docker registry in the airgap here like some other solutions have done. The answer is: This demo is meant to showcase a sustainable solution and building temporary docker registries locally is not a sustainable (nor a secure) solution for a real enterprise deployment. It's clever to be sure and is great for building out a PoC that has no intention of living for long. But it will not scale well for obvious reasons and from a security standpoint an insecure registry is not something you'd ever run in production. In the real enterprise, we manage the images we host internally via a real process involving several gates. Using a temporary Docker registry bypasses those gates for expediency but breaks any capability for declarative upgrades and attestation. So there's going to be some manual provisioning to get started here. Pulling the images into the airgap for each upgrade is generally its own process.

After manually provisioning, we'll redo the scenario using Terraform and prebuild a node VM image that contains all binaries on it that we need thus turning our bootstrap mechanism into a configuration-as-code pattern.

### What is an AirGap?
The term `airgap` is as ambiguous around the tech industry as the words `BBQ` around the world. Depending on who you talk to, it can mean something totally different and not just the actual implementation but the processes/rules around it too.

We'll simplify the discussion and separate airgaps into two distinct categories here: soft and hard. Throughout this document, we'll reference various things to consider when handling either type, but the demo will be based around a soft airgap.

The `hard airgap` is pretty self explanatory in that the network and systems running in that network are physically airgapped and likely have process and security controls around them where even using direct connects and certain physical media like USB drives is prevented or not allowed. The hard airgap is more common in the SCIF and can be a bit more difficult to navigate depending on implementation of network services like DHCP and DNS. There is very rarely any kind of internet access in these environments, so it should be assumed it will not be there. When accessing this kind of airgap, there will usually be some kind of workstation inside the gap that can be used to make changes to the environment. Because of this, all images must be copied to an allowable physical media (such as bluray) based on security controls and then physically brought into the environment at this workstation.

The `soft airgap` can be a bit more ambiguous than the hard variety, but it uses software (usually) to separate the environments at the network level. This is usually via the usage of VLANs and robust firewalls that control where network packets can go and what kinds are allowed. In these environments, internet access is usually non-existant or heavily regulated by ACLs. It is this kind of airgap that we will use. Here, a jumpbox can usually be made use of that the local user has specific access to. From that jumpbox, the user can interact with the environment (but not outside of it). In this case, the images and binaries would need to be copied up to the jumpbox before being pushed into the environment. We'll be using an Ubuntu 20.04 jumpbox here.

## Airgap Prereqs
* Infrastructure on which to deploy (we use Harvester here, but just about anything works) and that infra being configured.
* Linux or MacOS terminal with airgap access
* DHCP (static is possible, but adds extra provisioning steps)
* DNS
* Image Store (we use Harbor in our infrastructure)
* [RKE2 v1.24.8+rke2r1](https://github.com/rancher/rke2/releases/tag/v1.24.8%2Brke2r1) binaries
* [Rancher RCM 2.7.0](https://github.com/rancher/rancher/releases/tag/v2.7.0) binaries
* RKE2 Install Script
* kubevip

### Image Repo
When working in an airgap, it is necessary to bring all of your container images into a trusted source. This is usually called generically an `Image Store`. This location is a centralized source of truth that your RKE2 cluster, Rancher Cluster Manager, and all downstream clusters in this environment can pull their container images from (as opposed to the public cloud).

In order to do this, you'll need to pull down all of these images onto a local workstation and then either copy them into your soft-airgap via jumpbox or bring into your hard airgap using physical media like BluRay or a USB key drive. Be aware that the total image size is >30Gbi! The instructions for this process and some very helpful scripts are provided here and details around them defined in [the manual install doc](./manual_install.md).

# Provisioning with Terraform
Terraform is an infrastructure provisioning tool that we can use to spin up airgapped RKE2 and Rancher instances in a more automated way. This also provides the benefits of defining these components in a declaractive, stateful way. This greatly reduces toil and mostly eliminates all of the steps in the previous section.

We can also find a shortcut in this process speed-wise by creating prebuilt VM images that already contain every necessary component on them and them import those VM images into our airgap as well.

> * [Prep Harvester Image](#prep-harvesters-ubuntu-os-image)
> * [Prep Terraform](#prep-terraform)
> * [Terraform Tour](#terraform-tour)
> * [Install via Terraform](#install-via-terraform)

## Prep Harvester's Ubuntu OS Image
Please see the doc located in [the vm image doc](./vm_image_create.md) to dive into how I created the OS images here.

## Prep Terraform
We're going to be using Terraform to provision Harvester-level components and use K8S as a stateful storage. And we're going to keep it relatively simple, so no custom modules. For this, we'll need the Harvester provider among a few other things. This is defined in the [provider.tf](terraform/provider.tf) file.

Also, we'll want to refer to the vlan network we've been using, `services` in my case. Because this was created in the past or with a different set of terraform code, I reference this pre-existing resource using the `data` type. To make it obvious, I put those objects in the [data.tf](terraform/data.tf) file.

I also need to reference the VM image that I built so I can use it to construct VMs. In my local demo I just host this with a simple web instance using python. But in the real world, I probably have it available for download from an endpoint inside my airgap. I made a variable around the url for this endpoint named `rke2_image_url`. I will copy [terraform.tfvars.example](terraform/terraform.tfvars.example) to `terraform.tfvars` and set this value as well as the name of the image.

Along with those, I need to set what my hostname will be for my rancher instance. If you already followed the manual steps in the other doc, you'll know I chose `rancher.home.sienarfleet.systems`. 

Finally, I need to define my VIP or `virtual IP` for my RKE2 cluster. Internally I use `kube-vip` to define an additional static IP for my control-plane node to support HA control-planes and generally keep things simpler. Part of that is defining the IP I want, which is a variable called `master_vip`.

My final `terraform.tfvars` file:
```hcl
ubuntu_image_name = "ubuntu-rke2-airgap-harvester"
rke2_image_url = "http://10.10.0.248:9900/ubuntu-rke2-airgap-harvester.img"
rke2_registry = "harbor.sienarfleet.systems"

rancher_server_dns = "rancher.home.sienarfleet.systems"
master_vip = "10.10.5.4"
```

Due to Terraform's cloud-connected nature, we need to prepopulate our terraform directory with everything we need to run within our environment (and then copy everything into our airgap):
```bash
cd terraform
terraform init
terraform plan
```

## Terraform Tour
One of the powerful features of Terraform is it allows us to templatize things like cloud-init where we can write a generic expression that then can work for all similar cases with simple variable tweaks. We're not going crazy here, but I've extracted a few hardcoded values into a [variables.tf](terraform/variables.tf) file that allows us to define some defaults and potentially override them later using the above-defined `terraform.tfvars` file if we want to try different options out. We're also going to generate an SSH key as part of this.

Upon inspection of the control-plane node Terraform spec, we can see where the cloud-init has become templatized! Keep in mind how much manual effort this was to define (if you have been through the manual installation already). Also note vs our earlier cloud-init config, we are no longer downloading any code; we're just running the scripts we pre-installed in the image-creation steps above.
```hcl
cloudinit {
  type      = "noCloud"
  user_data    = <<EOT
    #cloud-config
    write_files:
    - path: /etc/rancher/rke2/config.yaml
      owner: root
      content: |
        token: ${var.cluster_token}
        server: https://${var.cp-hostname}:9345
        system-default-registry: ${var.rke2_registry}
    - path: /etc/hosts
      owner: root
      content: |
        127.0.0.1 localhost
        127.0.0.1 ${var.worker-hostname}
        ${var.master_vip} ${var.cp-hostname}
    - path: /etc/rancher/rke2/registries.yaml
      owner: root
      content: |
        mirrors:
          docker.io:
            endpoint:
              - "https://${var.rke2_registry}"
          ${var.rke2_registry}:
            endpoint:
              - "https://${var.rke2_registry}"
    runcmd:
    - - systemctl
      - enable
      - '--now'
      - qemu-guest-agent.service
    - INSTALL_RKE2_TYPE="agent" INSTALL_RKE2_ARTIFACT_PATH=/var/lib/rancher/rke2-artifacts sh /var/lib/rancher/install.sh
    - systemctl enable rke2-agent.service
    - systemctl start rke2-agent.service
    ssh_authorized_keys: 
    - ${tls_private_key.rsa_key.public_key_openssh}
  EOT
  network_data = ""
}
```

### Harvester Kubeconfig

Before running Terraform, we'll need to pull down the kubeconfig of our Harvester cluster. In Harvester, this can be acquired by going to the `Support` page via clicking the link in the bottom-left corner of the screen. After this, click the `Download kubeconfig` button and save it to your local workstation. If you are not using Harvester, this Terrform will need to be modified to suit your environment. I'll use `kubecm` here to manage my kubecontext.

```console
> kubecm add -f harvester.yaml
Add Context: harvester 
👻 True
「harvester.yaml」 write successful!
+------------+----------------+-----------------------+-----------------------+-----------------------------------+--------------+
|   CURRENT  |      NAME      |        CLUSTER        |          USER         |               SERVER              |   Namespace  |
+============+================+=======================+=======================+===================================+==============+
|     *      |    harvester   |         local         |         local         |   https://10.10.0.4/k8s/clusters  |    default   |
|            |                |                       |                       |               /local              |              |
+------------+----------------+-----------------------+-----------------------+-----------------------------------+--------------+
```

### Test Terraform

So let's test the Terraform environment and ensure it has everything we need. As part of this, I have the previously-mentioned python3 service running to host the image live. You should see no errors as of running the commands below:

```bash
cd terraform
terraform init
terraform plan
```

Ensure there are no errors! Keep in mind, in a true airgap, we'd need to do these steps in order to pre-download the Terraform modules that we need. Once we've run these steps, we can zip them up and copy them into the airgap by whatever means you have defined in your process. 

## Install via Terraform
Now that all the previous steps are done, we can call `terraform apply` and create our airgapped RKE2+Rancher instance in a declarative fashion! We can also now continuously make changes to the Terraform code and add/update components without tearing the whole thing down.

```bash
terraform apply
```

Truncated results:
```console
> terraform apply
data.harvester_network.services: Reading...
data.harvester_network.services: Read complete after 0s [id=default/services]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the
following symbols:
  + create

Terraform will perform the following actions:

...

Plan: 9 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

harvester_image.ubuntu-rke2: Creating...
tls_private_key.rsa_key: Creating...
tls_private_key.rsa_key: Creation complete after 1s [id=1159e974801abcb6659d1f966364998a2afb60c4]
harvester_ssh_key.rke2-key: Creating...
harvester_ssh_key.rke2-key: Creation complete after 0s [id=default/rke2-key]
harvester_image.ubuntu-rke2: Still creating... [10s elapsed]
harvester_image.ubuntu-rke2: Still creating... [20s elapsed]
harvester_image.ubuntu-rke2: Still creating... [30s elapsed]
harvester_image.ubuntu-rke2: Creation complete after 30s [id=default/ubuntu-rke2-airgap-harvester]
harvester_virtualmachine.cp-node: Creating...
...
harvester_virtualmachine.cp-node: Still creating... [2m0s elapsed]
harvester_virtualmachine.cp-node (remote-exec): Completed cloud-init!
harvester_virtualmachine.cp-node: Creation complete after 2m10s [id=default/rke2-airgap-cp]
...
harvester_virtualmachine.worker-node: Still creating... [1m30s elapsed]
harvester_virtualmachine.worker-node (remote-exec): Completed cloud-init!
harvester_virtualmachine.worker-node: Creation complete after 1m36s [id=default/rke2-airgap-worker]
helm_release.cert_manager: Creating...
helm_release.cert_manager: Creation complete after 20s [id=cert-manager]
helm_release.rancher_server: Creating...
helm_release.rancher_server: Still creating... [1m0s elapsed]
helm_release.rancher_server: Creation complete after 1m2s [id=rancher]

Apply complete! Resources: 9 added, 0 changed, 0 destroyed.

 ~/rancher/airgapping-made-easy/terraform | on main !1 ?3                                      took 5m 40s | at 09:27:45 
> 

```

At this point, Rancher is now starting! By the internal timer it only took 5m and 40s!!! That's fast! I can use the local kubeconfig that was generated as part of Terraform to view the cluster with `kubectl`
```console
kubecm add -f kube_config.yaml
Add Context: kube_config 
👻 True
「kube_config.yaml」 write successful!
+------------+----------------+-----------------------+-----------------------+-----------------------------------+--------------+
|   CURRENT  |      NAME      |        CLUSTER        |          USER         |               SERVER              |   Namespace  |
+============+================+=======================+=======================+===================================+==============+
|      *     |    harvester   |         local         |         local         |   https://10.10.0.4/k8s/clusters  |    default   |
|            |                |                       |                       |               /local              |              |
+------------+----------------+-----------------------+-----------------------+-----------------------------------+--------------+
|            |   kube_config  |   default-kg2b9m5685  |   default-kg2b9m5685  |       https://10.10.5.4:6443      |    default   |
+------------+----------------+-----------------------+-----------------------+-----------------------------------+--------------+

> kubectx kube_config
Switched to context "kube_config".
> kc get nodes
NAME                 STATUS   ROLES                       AGE   VERSION
rke2-airgap-cp       Ready    control-plane,etcd,master   12m   v1.24.8+rke2r1
rke2-airgap-worker   Ready    <none>                      10m   v1.24.8+rke2r1
> kubectx kube_config
Switched to context "kube_config".

> kc get po -n cattle-system
NAME                               READY   STATUS      RESTARTS   AGE
helm-operation-bg7cp               0/2     Completed   0          2m49s
helm-operation-hw8sr               0/2     Completed   0          2m42s
helm-operation-xkn7q               0/2     Completed   0          2m36s
helm-operation-z7tfs               0/2     Completed   0          3m8s
rancher-8446bc58f5-cgj2r           1/1     Running     0          4m2s
rancher-webhook-6954b76798-vtwtf   1/1     Running     0          2m34s
```

I can now hop into my Rancher instance at `rancher.home.sienarfleet.systems` and set a password then view the dashboard!
![rancher-dash](images/rancher-dash.png)

# Conclusion
That concludes these walk-throughs. I'm hopeful the information within is useful and you're able to re-use some of it to shortcut yourself to success and maybe learn about new things!

Feel free to reach out to me via email: brian.durden@rancherfederal.com