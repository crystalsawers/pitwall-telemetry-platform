# Create an Ubuntu Compute Engine VM
resource "google_compute_instance" "ubuntu_vm" {
  name         = "terraform-pitwall-vm"
  machine_type = "e2-medium"
  zone         = "australia-southeast1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2604-lts-amd64"
    }
  }

# Use the Custom VPC network
  network_interface {
  network    = google_compute_network.pitwall_vpc.id
  subnetwork = google_compute_subnetwork.pitwall_subnet.id

  access_config {} # Automatically assigns an External IP
}
    # Upload the install-stack.sh script to setup the pitwall
    metadata_startup_script = file("scripts/install-stack.sh")

}