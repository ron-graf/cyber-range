# --- VPC ---
resource "google_compute_network" "range_vpc" {
  name                    = "smallco-range"
  auto_create_subnetworks = false
}

# --- Subnets ---
resource "google_compute_subnetwork" "dmz" {
  name          = "dmz"
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.range_vpc.id
  region        = var.region
}

resource "google_compute_subnetwork" "internal" {
  name          = "internal"
  ip_cidr_range = "10.0.2.0/24"
  network       = google_compute_network.range_vpc.id
  region        = var.region
}

resource "google_compute_subnetwork" "admin" {
  name          = "admin"
  ip_cidr_range = "10.0.3.0/24"
  network       = google_compute_network.range_vpc.id
  region        = var.region
}

# --- Cloud Router + NAT (so VMs without public IPs can pull packages) ---
resource "google_compute_router" "router" {
  name    = "range-router"
  network = google_compute_network.range_vpc.id
  region  = var.region
}

resource "google_compute_router_nat" "nat" {
  name                               = "range-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
