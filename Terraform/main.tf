# Specify the Terraform provider
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

# Configure the Google Cloud provider
provider "google" {
  project = "project-id"
  region  = "australia-southeast1"
  zone    = "australia-southeast1-a"
}