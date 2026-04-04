output "attacker_public_ip" {
  description = "Public IP of the attacker jump box"
  value       = google_compute_instance.attacker.network_interface[0].access_config[0].nat_ip
}

output "web_server_ip" {
  value = google_compute_instance.web_server.network_interface[0].network_ip
}

output "workstation_1_ip" {
  value = google_compute_instance.workstation_1.network_interface[0].network_ip
}

output "workstation_2_ip" {
  value = google_compute_instance.workstation_2.network_interface[0].network_ip
}

output "db_server_ip" {
  value = google_compute_instance.db_server.network_interface[0].network_ip
}

output "file_server_ip" {
  value = google_compute_instance.file_server.network_interface[0].network_ip
}

output "admin_server_ip" {
  value = google_compute_instance.admin_server.network_interface[0].network_ip
}

output "ansible_inventory" {
  description = "Generated Ansible inventory content"
  value = templatefile("${path.module}/inventory.tftpl", {
    attacker_ip     = google_compute_instance.attacker.network_interface[0].access_config[0].nat_ip
    web_server_ip   = google_compute_instance.web_server.network_interface[0].network_ip
    workstation_1_ip = google_compute_instance.workstation_1.network_interface[0].network_ip
    workstation_2_ip = google_compute_instance.workstation_2.network_interface[0].network_ip
    db_server_ip    = google_compute_instance.db_server.network_interface[0].network_ip
    file_server_ip  = google_compute_instance.file_server.network_interface[0].network_ip
    admin_server_ip = google_compute_instance.admin_server.network_interface[0].network_ip
    ssh_user        = var.ssh_user
  })
}
