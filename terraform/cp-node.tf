resource "harvester_virtualmachine" "cp-node" {
  name                 = "${var.cp-hostname}"
  namespace            = "default"
  restart_after_update = true

  description = "Mgmt Cluster Control Plane node"
  tags = {
    ssh-user = "ubuntu"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait > /dev/null",
      "echo 'Completed cloud-init!'",
    ]

    connection {
      type        = "ssh"
      host        = self.network_interface[index(self.network_interface.*.name, "default")].ip_address
      user        = "ubuntu"
      private_key = tls_private_key.rsa_key.private_key_pem
    }
  }

  cpu    = 2
  memory = "4Gi"

  run_strategy = "RerunOnFailure"
  hostname     = "${var.cp-hostname}"
  machine_type = "q35"

  ssh_keys = []
  network_interface {
    name           = "default"
    network_name   = data.harvester_network.services.id
    wait_for_lease = true
  }

  disk {
    name       = "rootdisk"
    type       = "disk"
    size       = "40Gi"
    bus        = "virtio"
    boot_order = 1

    image       = harvester_image.ubuntu-rke2.id
    auto_delete = true
  }

  cloudinit {
    type      = "noCloud"
    user_data    = <<EOT
      #cloud-config
      write_files:
      - path: /etc/rancher/rke2/config.yaml
        owner: root
        content: |
          token: ${var.cluster_token}
          system-default-registry: ${var.rke2_registry}
          tls-san:
            - ${var.cp-hostname}
            - ${var.master_vip}
      - path: /etc/hosts
        owner: root
        content: |
          127.0.0.1 localhost
          127.0.0.1 ${var.cp-hostname}
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
            ghcr.io:
              endpoint:
                - "https://${var.rke2_registry}"
      runcmd:
      - - systemctl
        - enable
        - '--now'
        - qemu-guest-agent.service
      - INSTALL_RKE2_ARTIFACT_PATH=/var/lib/rancher/rke2-artifacts sh /var/lib/rancher/install.sh
      - cat /var/lib/rancher/kube-vip-k3s |  vipAddress=${var.master_vip} vipInterface=${var.master_vip_interface} sh | sudo tee /var/lib/rancher/rke2/server/manifests/vip.yaml
      - systemctl enable rke2-server.service
      - systemctl start rke2-server.service
      ssh_authorized_keys: 
      - ${tls_private_key.rsa_key.public_key_openssh}
    EOT
    network_data = ""
  }
}