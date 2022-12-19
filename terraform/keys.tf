resource "tls_private_key" "rsa_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "harvester_ssh_key" "rke2-key" {
  name      = "rke2-key"
  namespace = "default"

  public_key = tls_private_key.rsa_key.public_key_openssh
}
