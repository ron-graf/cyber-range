locals {
  ssh_key = "${var.ssh_user}:${file(var.ssh_pub_key_file)}"

  spot_config = var.use_spot ? {
    provisioning_model  = "SPOT"
    preemptible         = true
    automatic_restart   = false
    on_host_maintenance = "TERMINATE"
  } : {
    provisioning_model  = "STANDARD"
    preemptible         = false
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }
}

# --- Attacker (jump box) ---
resource "google_compute_instance" "attacker" {
  name         = "attacker"
  machine_type = "e2-small"
  zone         = var.zone
  tags         = ["attacker"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.dmz.id
    network_ip = "10.0.1.10"
    access_config {} # Public IP for SSH access
  }

  metadata = {
    ssh-keys = local.ssh_key
  }

  scheduling {
    provisioning_model  = local.spot_config.provisioning_model
    preemptible         = local.spot_config.preemptible
    automatic_restart   = local.spot_config.automatic_restart
    on_host_maintenance = local.spot_config.on_host_maintenance
  }
}

# --- DMZ: Web Server ---
resource "google_compute_instance" "web_server" {
  name         = "web-server"
  machine_type = "e2-small"
  zone         = var.zone
  tags         = ["dmz", "dmz-web"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 15
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.dmz.id
    network_ip = "10.0.1.20"
  }

  metadata = {
    ssh-keys = local.ssh_key
  }

  scheduling {
    provisioning_model  = local.spot_config.provisioning_model
    preemptible         = local.spot_config.preemptible
    automatic_restart   = local.spot_config.automatic_restart
    on_host_maintenance = local.spot_config.on_host_maintenance
  }
}

# --- Internal: Workstation 1 ---
resource "google_compute_instance" "workstation_1" {
  name         = "workstation-1"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["internal"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 10
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.internal.id
    network_ip = "10.0.2.10"
  }

  metadata = {
    ssh-keys = local.ssh_key
  }

  scheduling {
    provisioning_model  = local.spot_config.provisioning_model
    preemptible         = local.spot_config.preemptible
    automatic_restart   = local.spot_config.automatic_restart
    on_host_maintenance = local.spot_config.on_host_maintenance
  }
}

# --- Internal: Workstation 2 ---
resource "google_compute_instance" "workstation_2" {
  name         = "workstation-2"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["internal"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 10
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.internal.id
    network_ip = "10.0.2.11"
  }

  metadata = {
    ssh-keys = local.ssh_key
  }

  scheduling {
    provisioning_model  = local.spot_config.provisioning_model
    preemptible         = local.spot_config.preemptible
    automatic_restart   = local.spot_config.automatic_restart
    on_host_maintenance = local.spot_config.on_host_maintenance
  }
}

# --- Internal: Database Server ---
resource "google_compute_instance" "db_server" {
  name         = "db-server"
  machine_type = "e2-small"
  zone         = var.zone
  tags         = ["internal"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 15
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.internal.id
    network_ip = "10.0.2.20"
  }

  metadata = {
    ssh-keys = local.ssh_key
  }

  scheduling {
    provisioning_model  = local.spot_config.provisioning_model
    preemptible         = local.spot_config.preemptible
    automatic_restart   = local.spot_config.automatic_restart
    on_host_maintenance = local.spot_config.on_host_maintenance
  }
}

# --- Internal: File Server ---
resource "google_compute_instance" "file_server" {
  name         = "file-server"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["internal"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 10
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.internal.id
    network_ip = "10.0.2.30"
  }

  metadata = {
    ssh-keys = local.ssh_key
  }

  scheduling {
    provisioning_model  = local.spot_config.provisioning_model
    preemptible         = local.spot_config.preemptible
    automatic_restart   = local.spot_config.automatic_restart
    on_host_maintenance = local.spot_config.on_host_maintenance
  }
}

# --- Admin: Admin Server (final target) ---
resource "google_compute_instance" "admin_server" {
  name         = "admin-server"
  machine_type = "e2-small"
  zone         = var.zone
  tags         = ["admin"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 10
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.admin.id
    network_ip = "10.0.3.10"
  }

  metadata = {
    ssh-keys = local.ssh_key
  }

  scheduling {
    provisioning_model  = local.spot_config.provisioning_model
    preemptible         = local.spot_config.preemptible
    automatic_restart   = local.spot_config.automatic_restart
    on_host_maintenance = local.spot_config.on_host_maintenance
  }
}
