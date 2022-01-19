output "Lab_IPs" {
  value = metal_device.lab.*.access_public_ipv4
}
