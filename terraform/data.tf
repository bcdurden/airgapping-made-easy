data "harvester_network" "services" {
  name      = "services"
  namespace = "default"
}
data "harvester_image" "ubuntu-rke2" {
  name     = "image-jfbsk"
  namespace = "default"
}
