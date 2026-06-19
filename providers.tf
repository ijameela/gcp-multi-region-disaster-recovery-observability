terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = "project-57cb896b-79a5-4193-a8b"
  region  = "us-central1"
  zone    = "us-central1-a"
}

