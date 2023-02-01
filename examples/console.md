

## Image Migration

### Scripts
Copying scripts to jumpbox:

```console
> scp -i ~/.ssh/harvester_test pull_rancher ubuntu@10.10.5.190:./
pull_rancher                                                                                                                100% 3022   292.7KB/s   00:00    
> scp -i ~/.ssh/harvester_test pull_rke2 ubuntu@10.10.5.190:./
pull_rke2                                                                                                                   100%  458   106.2KB/s   00:00    
> scp -i ~/.ssh/harvester_test push_images ubuntu@10.10.5.190:./
push_images                                                                                                                 100%  999   102.6KB/s   00:00    
```

### Pulling Images
On the jumpbox, and pulling all images down!
RKE2:
```console
ubuntu@jumpbox:~$ ./pull_rke2 
--2022-12-15 19:50:47--  https://github.com/rancher/rke2/releases/download/v1.24.8+rke2r1/rke2-images.linux-amd64.tar.zst
Resolving github.com (github.com)... 140.82.114.3
Connecting to github.com (github.com)|140.82.114.3|:443... connected.
...
Saving to: ‘rke2-images.linux-amd64.tar.zst’

rke2-images.linux-amd64.tar.zst         100%[=============================================================================>] 774.73M  15.4MB/s    in 46s     

2022-12-15 19:51:33 (17.0 MB/s) - ‘rke2-images.linux-amd64.tar.zst’ saved [812363060/812363060]

--2022-12-15 19:51:33--  https://github.com/rancher/rke2/releases/download/v1.24.8+rke2r1/rke2.linux-amd64.tar.gz
Resolving github.com (github.com)... 140.82.114.3
Connecting to github.com (github.com)|140.82.114.3|:443... connected.
...
Saving to: ‘rke2.linux-amd64.tar.gz’

rke2.linux-amd64.tar.gz.1               100%[=============================================================================>]  46.11M  24.7MB/s    in 1.9s    

2022-12-15 19:51:35 (24.7 MB/s) - ‘rke2.linux-amd64.tar.gz.1’ saved [48350150/48350150]

--2022-12-15 19:51:35--  https://github.com/rancher/rke2/releases/download/v1.24.8+rke2r1/sha256sum-amd64.txt
Resolving github.com (github.com)... 140.82.113.3
Connecting to github.com (github.com)|140.82.113.3|:443... connected.
...
Length: 3626 (3.5K) [application/octet-stream]
Saving to: ‘sha256sum-amd64.txt’

sha256sum-amd64.txt.1                   100%[=============================================================================>]   3.54K  --.-KB/s    in 0.001s  

2022-12-15 19:51:35 (5.88 MB/s) - ‘sha256sum-amd64.txt.1’ saved [3626/3626]

```

Rancher:
```console
ubuntu@jumpbox:~$ ./pull_rancher 
"jetstack" has been added to your repositories
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "jetstack" chart repository
Update Complete. ⎈Happy Helming!⎈
Exporting quay.io/jetstack/cert-manager-cainjector:v1.8.1
Exporting quay.io/jetstack/cert-manager-controller:v1.8.1
Exporting quay.io/jetstack/cert-manager-webhook:v1.8.1
Exporting quay.io/jetstack/cert-manager-ctl:v1.8.1
Exporting rancher/aks-operator:v1.0.7
Exporting rancher/backup-restore-operator:v3.0.0
Exporting rancher/calico-cni:v3.22.0-rancher1
Exporting rancher/cis-operator:v1.0.10
Exporting rancher/coreos-kube-state-metrics:v1.9.7
Exporting rancher/coreos-prometheus-config-reloader:v0.38.1
Exporting rancher/coreos-prometheus-operator:v0.38.1
Exporting rancher/eks-operator:v1.1.5
Exporting rancher/externalip-webhook:v1.0.1
Exporting rancher/flannel-cni:v0.3.0-rancher6
Exporting rancher/fleet-agent:v0.5.0
...
Exporting rancher/system-upgrade-controller:v0.9.1
Exporting rancher/tekton-utils:v0.1.7
Exporting rancher/thanosio-thanos:v0.15.0
Exporting rancher/ui-plugin-operator:v0.1.0
Exporting rancher/webhook-receiver:v0.2.4
Exporting rancher/webhook-receiver:v0.2.5
Compresing Rancher images...
ubuntu@jumpbox:~$ ll /tmp/*.tar.gz
-rw-rw-r-- 1 ubuntu ubuntu   322077582 Dec 16 15:46 /tmp/cert-manager-images.tar.gz
-rw-rw-r-- 1 ubuntu ubuntu 77127547828 Dec 16 17:18 /tmp/rancher-images.tar.gz
```

### Pushing Images

First I'll push my cert-manager images, they require a `jetstack` project to exist if using Harbor so ensure you've created that. And in my case I am using a public-read-only registry. The same needs to be set for a `rancher` project.
```console
ubuntu@jumpbox:~$ ./push_images harbor.sienarfleet.systems admin 'my_password' /tmp/cert-manager-images.tar.gz 
auth.go:191: logged in via /home/ubuntu/.docker/config.json
===>Pushing harbor.sienarfleet.systems/jetstack/cert-manager-cainjector:v1.8.1
===>Pushing harbor.sienarfleet.systems/jetstack/cert-manager-controller:v1.8.1
===>Pushing harbor.sienarfleet.systems/jetstack/cert-manager-webhook:v1.8.1
===>Pushing harbor.sienarfleet.systems/jetstack/cert-manager-ctl:v1.8.1
```

Then I'll push rancher (will take a while):
```console
ubuntu@jumpbox:~$ ./push_images harbor.sienarfleet.systems admin 'my_password' /tmp/rancher-images.tar.gz 
auth.go:191: logged in via /home/ubuntu/.docker/config.json
===>Pushing harbor.sienarfleet.systems/rancher/aks-operator:v1.0.7
===>Pushing harbor.sienarfleet.systems/rancher/backup-restore-operator:v3.0.0
===>Pushing harbor.sienarfleet.systems/rancher/calico-cni:v3.22.0-rancher1
===>Pushing harbor.sienarfleet.systems/rancher/cis-operator:v1.0.10
===>Pushing harbor.sienarfleet.systems/rancher/coreos-kube-state-metrics:v1.9.7
...
===>Pushing harbor.sienarfleet.systems/rancher/system-agent-installer-rke2:v1.24.2-rke2r1
===>Pushing harbor.sienarfleet.systems/rancher/system-agent-installer-rke2:v1.24.4-rke2r1
===>Pushing harbor.sienarfleet.systems/rancher/system-agent-installer-rke2:v1.24.7-rke2r1
===>Pushing harbor.sienarfleet.systems/rancher/system-agent:v0.2.13-suc
===>Pushing harbor.sienarfleet.systems/rancher/system-upgrade-controller:v0.9.1
===>Pushing harbor.sienarfleet.systems/rancher/tekton-utils:v0.1.7
===>Pushing harbor.sienarfleet.systems/rancher/thanosio-thanos:v0.15.0
===>Pushing harbor.sienarfleet.systems/rancher/ui-plugin-operator:v0.1.0
===>Pushing harbor.sienarfleet.systems/rancher/webhook-receiver:v0.2.4
===>Pushing harbor.sienarfleet.systems/rancher/webhook-receiver:v0.2.5
```

## Starting the Control Plane Node

```console
ubuntu@rke2-airgap-cp:~$ sudo INSTALL_RKE2_ARTIFACT_PATH=/home/ubuntu sh install_rke2.sh
[INFO]  staging local checksums from /home/ubuntu/sha256sum-amd64.txt
[INFO]  staging zst airgap image tarball from /home/ubuntu/rke2-images.linux-amd64.tar.zst
[INFO]  staging tarball from /home/ubuntu/rke2.linux-amd64.tar.gz
[INFO]  verifying airgap tarball
grep: /tmp/rke2-install.u5eyvQnyMa/rke2-images.checksums: No such file or directory
[INFO]  installing airgap tarball to /var/lib/rancher/rke2/agent/images
[INFO]  verifying tarball
[INFO]  unpacking tarball file to /usr/local
```

```console
ubuntu@rke2-airgap-cp:~$ sudo systemctl enable rke2-server.service
Created symlink /etc/systemd/system/multi-user.target.wants/rke2-server.service → /usr/local/lib/systemd/system/rke2-server.service.
ubuntu@rke2-airgap-cp:~$ sudo systemctl start rke2-server.service
ubuntu@rke2-airgap-cp:~$
```

### Get kubeconfig
At this point, the control-plane node is starting. We can grab the kubeconfig from `/etc/rancher/rke2/rke2.yaml` and change its permissions to copy to our jumpbox.
```console
ubuntu@rke2-airgap-cp:~$ sudo cp /etc/rancher/rke2/rke2.yaml config
ubuntu@rke2-airgap-cp:~$ sudo chown ubuntu: config
```

Now copy the file down and change the API endpoint to our VIP
```console
ubuntu@rke2-airgap-cp:~$ exit
logout
Connection to 10.10.5.226 closed.
ubuntu@jumpbox:~$ scp -i ~/.ssh/harvester_test ubuntu@10.10.5.226:./config .
config                                                                                          100% 2969     6.4MB/s   00:00    
ubuntu@jumpbox:~$ mkdir .kube
ubuntu@jumpbox:~$ mv config .kube/
ubuntu@jumpbox:~$ sed -ie 's/127.0.0.1/10.10.5.4/g' .kube/config
```

Verify the control-plane node is running using `kubectl`:
```console
ubuntu@jumpbox:~$ kubectl get nodes
NAME             STATUS   ROLES                       AGE     VERSION
rke2-airgap-cp   Ready    control-plane,etcd,master   4m22s   v1.24.8+rke2r1
```