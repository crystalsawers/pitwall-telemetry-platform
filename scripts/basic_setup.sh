#!/bin/bash

# For the VM you NEED to run as root, otherwise this wont work
if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo: sudo $0"
  echo "Use 'sudo -i' to get a root shell and then run the script. You will get 'root@pitwall-vm:~# '"
  exit 1
fi

# Update and upgrade the system, then install necessary base packages

apt update &&  apt upgrade -y
apt install -y git curl ufw ca-certificates

# Enable UFW and allow necessary ports (e.g., SSH, HTTP, HTTPS)
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8000/tcp
ufw allow 5432/tcp
ufw --force enable

# Setup Docker Apt repository (this is from Docker's official installation instructions for Ubuntu)

# Add Docker's official GPG key:
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

# Install Docker Engine
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Verify Docker is running
systemctl status docker

if [ $? -ne 0 ]; then
    echo "Docker is not running. Starting Docker."
    systemctl start docker
    systemctl enable docker
fi

# Add current user to the docker group to run Docker without sudo
usermod -aG docker $USER
echo "Basic setup completed. Please log out and log back in to apply Docker group changes."
echo "You can verify Docker installation by running 'docker run hello-world' after logging back in, and then 'docker ps' to check."