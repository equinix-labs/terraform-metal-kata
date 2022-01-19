
resource "null_resource" "add-lab-user" {

  count = var.lab_count

  connection {
    user        = "root"
    private_key = tls_private_key.default.private_key_pem
    agent       = false
    timeout     = "30s"
    host        = element(metal_device.lab.*.access_public_ipv4, count.index)
  }

  provisioner "remote-exec" {
    script = "${path.module}/assets/add-lab-user.sh"
  }
}
