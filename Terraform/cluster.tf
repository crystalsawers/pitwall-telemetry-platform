# ------------------------------------------------------------
# GKE CLUSTER
# ------------------------------------------------------------

resource "google_container_cluster" "f1_cluster" {
  name     = "f1-telemetry-cluster"
  location = "australia-southeast1"

  network    = google_compute_network.pitwall_vpc.name
  subnetwork = google_compute_subnetwork.pitwall_subnet.name

  private_cluster_config {
    enable_private_endpoint = false
    enable_private_nodes    = true
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  initial_node_count       = 1
  remove_default_node_pool = true

  deletion_protection = false
}

# ------------------------------------------------------------
# NODE POOL
# ------------------------------------------------------------

resource "google_container_node_pool" "f1_nodes" {
  name     = "f1-telemetry-nodes"
  location = "australia-southeast1"
  cluster  = google_container_cluster.f1_cluster.name

  node_count = 2

  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 30

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}

# ------------------------------------------------------------
# IAM
# ------------------------------------------------------------

resource "google_project_iam_member" "gke_admin" {
  project = "project-id" # <-- Fill in with your own project id
  role    = "roles/container.admin"
  member  = "user:your-gmail@gmail.com" # <-- Fill in with your gmail that's using Google Cloud
}

# ------------------------------------------------------------
# AUTO-CONFIGURE KUBECTL
# ------------------------------------------------------------

resource "null_resource" "get_credentials" {
  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials f1-telemetry-cluster --region=australia-southeast1 --project=project-id"
  }

  depends_on = [google_container_node_pool.f1_nodes]
}