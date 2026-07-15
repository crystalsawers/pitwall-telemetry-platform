# Create custom VPC network
resource "google_compute_network" "pitwall_vpc" {
  name                    = "pitwall-vpc"
  auto_create_subnetworks = false
}

# Create subnet
resource "google_compute_subnetwork" "pitwall_subnet" {
  name          = "pitwall-subnet"
  region        = "australia-southeast1"
  ip_cidr_range = "10.10.0.0/24"

  network = google_compute_network.pitwall_vpc.id
}

# Add firewall rules
# Allow SSH
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.pitwall_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Allow HTTP
resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = google_compute_network.pitwall_vpc.name

  allow {
    protocol = "tcp"
    ports = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Allow HTTPS
resource "google_compute_firewall" "allow_https" {
  name    = "allow-https"
  network = google_compute_network.pitwall_vpc.name

  allow {
    protocol = "tcp"
    ports = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Allow Grafana dashboard
resource "google_compute_firewall" "allow_grafana" {
  name    = "allow-grafana"
  network = google_compute_network.pitwall_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Allow internal communication within the VPC
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.pitwall_vpc.name

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.10.0.0/24"]
}

# CLOUD NAT (for private GKE nodes to reach internet)

resource "google_compute_router" "nat_router" {
  name    = "nat-router"
  region  = "australia-southeast1"
  network = google_compute_network.pitwall_vpc.name
}

resource "google_compute_router_nat" "nat" {
  name                               = "nat-config"
  router                             = google_compute_router.nat_router.name
  region                             = "australia-southeast1"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}