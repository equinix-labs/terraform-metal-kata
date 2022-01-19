provider "metal" {
  auth_token = var.metal_auth_token
}

resource "metal_ssh_key" "default" {
  name       = "default"
  public_key = tls_private_key.default.public_key_openssh
}

resource "metal_device" "lab" {
  depends_on = [metal_ssh_key.default]

  count            = var.lab_count
  hostname         = format("lab%02d", count.index)
  operating_system = var.operating_system
  plan             = var.plan

  connection {
    host        = self.access_public_ipv4
    user        = "root"
    private_key = tls_private_key.default.private_key_pem
    agent       = false
    timeout     = "30s"
  }
  facilities    = [var.metal_facility]
  project_id    = var.metal_project_id
  billing_cycle = "hourly"

  provisioner "file" {
    source      = "${path.module}/assets/install-kubectl.sh"
    destination = "install-kubectl.sh"
  }

  provisioner "file" {
    source      = "${path.module}/assets/install-virtualbox.sh"
    destination = "install-virtualbox.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "ssh-keygen -A",
      #      "bash hardware-setup.sh > hardware-setup.out",
    ]
  }
}
