variable "cp-hostname" {
    type = string
    default = "rke2-airgap-cp"
}
variable "worker-hostname" {
    type = string
    default = "rke2-airgap-worker"
}
variable "master_vip" {
    type = string
    default = "10.10.5.4"
}
variable "cluster_token" {
    type = string
    default = "my-shared-token"
}
variable "rke2_registry" {
    type = string
    default = "harbor.sienarfleet.systems"
}
variable "master_vip_interface" {
    type = string
    default = "enp1s0"
}
variable "kubeconfig_filename" {
    type = string
    default = "kube_config.yaml"
}
variable "cert_manager_version" {
    type = string
    default = "1.8.1"
}
variable "rancher_version" {
    type = string
    default = "2.7.0"
}
variable "rancher_server_dns" {
    type = string
    default = "rancher.home.sienarfleet.systems"
}
variable "rancher_bootstrap_password" {
    type = string
    default = "admin"
}