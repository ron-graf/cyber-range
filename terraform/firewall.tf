# --- Allow SSH from the internet to the attacker VM only ---
resource "google_compute_firewall" "allow_ssh_attacker" {
  name    = "allow-ssh-attacker"
  network = google_compute_network.range_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["attacker"]
}

# --- Allow HTTP/HTTPS to DMZ web server (simulates internet-facing) ---
resource "google_compute_firewall" "allow_web_dmz" {
  name    = "allow-web-dmz"
  network = google_compute_network.range_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["dmz-web"]
}

# --- DMZ can reach internal (simulates poorly segmented network) ---
resource "google_compute_firewall" "dmz_to_internal" {
  name    = "dmz-to-internal"
  network = google_compute_network.range_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22", "3306", "445", "139", "80", "8080"]
  }

  allow {
    protocol = "icmp"
  }

  source_tags = ["dmz"]
  target_tags = ["internal"]
}

# --- Internal hosts can talk to each other ---
resource "google_compute_firewall" "internal_internal" {
  name    = "internal-to-internal"
  network = google_compute_network.range_vpc.id

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_tags = ["internal"]
  target_tags = ["internal"]
}

# --- Internal can reach admin (lateral movement path) ---
resource "google_compute_firewall" "internal_to_admin" {
  name    = "internal-to-admin"
  network = google_compute_network.range_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  allow {
    protocol = "icmp"
  }

  source_tags = ["internal"]
  target_tags = ["admin"]
}

# --- Attacker can reach DMZ (simulates external attacker) ---
resource "google_compute_firewall" "attacker_to_dmz" {
  name    = "attacker-to-dmz"
  network = google_compute_network.range_vpc.id

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_tags = ["attacker"]
  target_tags = ["dmz", "dmz-web"]
}

# --- Allow internal ICMP for network discovery ---
resource "google_compute_firewall" "allow_icmp_all" {
  name    = "allow-icmp-internal"
  network = google_compute_network.range_vpc.id

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]
}
