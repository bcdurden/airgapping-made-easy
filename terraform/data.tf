data "harvester_network" "services" {
  name      = "services"
  namespace = "default"
}
resource "harvester_image" "ubuntu-rke2-airgap" {
  name      = "ubuntu-rke2-airgap"
  namespace = "default"

  display_name = "ubuntu-rke2-airgap"
  source_type  = "download"
  url          = "http://10.10.5.163:9900/ubuntu-rke2-airgap-harvester.img"
}
