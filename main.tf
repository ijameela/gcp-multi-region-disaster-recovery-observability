resource "google_compute_network" "vpc_network" {
  name                    = "dr-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "primary_subnet" {
  name          = "primary-subnet-us-central1"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_subnetwork" "dr_subnet" {
  name          = "dr-subnet-us-east1"
  ip_cidr_range = "10.0.2.0/24"
  region        = "us-east1"
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_firewall" "allow_monitoring" {
  name    = "allow-monitoring"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["3000", "9090", "22"]
  }
source_ranges = [var.admin_ip]
}

resource "google_service_account" "vm_sa" {
  account_id   = "web-server-sa"
  display_name = "Custom Service Account for Web Server VM"
}

resource "google_compute_instance" "primary_vm" {
  name                      = "prod-web-server"
  machine_type              = "e2-medium"
  zone                      = "us-central1-a"
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.primary_subnet.id
    access_config {
    }
  }

  service_account {
    email  = google_service_account.vm_sa.email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_global_address" "private_ip_alloc" {
  name          = "private-ip-alloc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc_network.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
}

resource "google_secret_manager_secret" "db_password_secret" {
  secret_id = "db-password"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password_version" {
  secret      = google_secret_manager_secret.db_password_secret.id
  secret_data = "SuperSecurePassword123!"
}

resource "google_sql_database_instance" "primary_db" {
  name             = "primary-db-instance"
  region           = "us-central1"
  database_version = "POSTGRES_15"
  depends_on       = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc_network.id
    }
    backup_configuration {
      enabled    = true
      start_time = "02:00"
    }
  }
  deletion_protection = true
}

resource "google_sql_database_instance" "replica_db" {
  name                 = "replica-db-instance"
  region               = "us-east1"
  database_version     = "POSTGRES_15"
  master_instance_name = google_sql_database_instance.primary_db.name

  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc_network.id
    }
  }
  deletion_protection = true
}

resource "google_sql_user" "db_user" {
  name     = "db-admin"
  instance = google_sql_database_instance.primary_db.name
  password = google_secret_manager_secret_version.db_password_version.secret_data
}

variable "admin_ip" {
  type        = string
  description = "The public IP address of the administrator allowed to access monitoring tools."
}
