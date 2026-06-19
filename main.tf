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

resource "google_compute_firewall" "allow_web_ssh" {
  name    = "allow-web-and-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "9090", "3000"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_instance" "primary_vm" {
  name         = "prod-web-server"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

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
  deletion_protection = false
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
  deletion_protection = false
}
