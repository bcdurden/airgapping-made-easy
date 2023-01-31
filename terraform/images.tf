resource "harvester_image" "ubuntu-rke2" {
  name      = var.ubuntu_image_name
  namespace = "default"

  display_name = var.ubuntu_image_name
  source_type  = "download"
  url          = var.rke2_image_url
}