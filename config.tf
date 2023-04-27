provider "google" {
  credentials = file("path/to/service-account-key.json")
  project     = "my-gcp-project-id"
  region      = "us-central1"
}

resource "google_sql_database_instance" "my-postgresql-instance" {
  name             = "my-postgresql-instance"
  database_version = "POSTGRES_13"

  settings {
    tier = "db-f1-micro"
  }
}

resource "google_sql_database" "my-postgresql-db" {
  name     = "my-postgresql-db"
  instance = google_sql_database_instance.my-postgresql-instance.name
}

resource "google_sql_user" "my-postgresql-user" {
  name     = "my-postgresql-user"
  password = "my-postgresql-password"
  instance = google_sql_database_instance.my-postgresql-instance.name
  host     = "%"
}

resource "google_compute_firewall" "my-postgresql-firewall" {
  name    = "my-postgresql-firewall"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_container_cluster" "my-kubernetes-cluster" {
  name               = "my-kubernetes-cluster"
  location           = "us-central1-a"
  initial_node_count = 1

  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 10
  }

  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }
}

provider "kubernetes" {
  load_config_file = false
  host             = google_container_cluster.my-kubernetes-cluster.endpoint
  username         = google_container_cluster.my-kubernetes-cluster.master_auth[0].username
  password         = google_container_cluster.my-kubernetes-cluster.master_auth[0].password

  cluster_ca_certificate = base64decode(google_container_cluster.my-kubernetes-cluster.master_auth[0].cluster_ca_certificate)
}

resource "kubernetes_namespace" "development" {
  metadata {
    name = "development"
  }
}

resource "kubernetes_namespace" "staging" {
  metadata {
    name = "staging"
  }
}

resource "kubernetes_deployment" "my-nodejs-deployment" {
  metadata {
    name      = "my-nodejs-deployment"
    namespace = kubernetes_namespace.development.metadata.0.name
  }

  spec {
    selector {
      match_labels = {
        app = "my-nodejs-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "my-nodejs-app"
        }
      }

      spec {
        container {
          name  = "my-nodejs-container"
          image = "my-nodejs-image:latest"

          env {
            name  = "DATABASE_URL"
            value = google_sql_database.my-postgresql-db.connection_name
          }

          ports {
            container_port = 8080
          }
        }
      }
    }
  }
}
