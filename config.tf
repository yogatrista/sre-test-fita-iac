provider "google" {
  credentials = file("key.json")
  project     = "local-env-384915"
  region      = "asia-southeast2"
}

resource "google_sql_database_instance" "postgre-sre-test-fita" {
  name             = "postgre-sre-test-fita"
  database_version = "POSTGRES_14"

  settings {
    tier = "db-f1-micro"
  }
}

resource "google_sql_database" "postgresql-db" {
  name     = "postgresql-db"
  instance = google_sql_database_instance.postgre-sre-test-fita.name
}

resource "google_sql_user" "postgresql-user" {
  name     = "postgresql-user"
  password = "postgresql-password"
  instance = google_sql_database_instance.postgre-sre-test-fita.name
}

resource "google_compute_firewall" "postgresql-firewall" {
  name    = "postgresql-firewall"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_container_cluster" "sre-test-cluster" {
  name               = "sre-test-cluster"
  location           = "asia-southeast2"
  initial_node_count = 1

  node_config {
    machine_type = "g1-small"
    disk_size_gb = 10
  }

  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }
}

provider "kubernetes" {
  host             = google_container_cluster.sre-test-cluster.endpoint
  cluster_ca_certificate = base64decode(google_container_cluster.sre-test-cluster.master_auth[0].cluster_ca_certificate)
}


