# ------------------------------------------------------------
# SECRET MANAGER
# ------------------------------------------------------------

resource "google_secret_manager_secret" "db_password" {
  secret_id = "f1-db-password"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password
}

# ------------------------------------------------------------
# CLOUD SQL
# ------------------------------------------------------------

resource "google_sql_database_instance" "f1_db" {
  name             = "f1-telemetry-db"
  database_version = "POSTGRES_18"
  region           = "australia-southeast1"

  settings {
    tier              = "db-perf-optimized-N-2"
    edition           = "ENTERPRISE_PLUS"
    availability_type = "ZONAL"

    disk_size = 100
    disk_type = "PD_SSD"

    ip_configuration {
      ipv4_enabled = true
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }

    data_cache_config {
      data_cache_enabled = true
    }
  }

  deletion_protection = false
}

resource "google_sql_database" "f1_database" {
  name     = "f1-telemetry"
  instance = google_sql_database_instance.f1_db.name
}


resource "google_sql_user" "f1_user" {
  name     = var.db_username
  instance = google_sql_database_instance.f1_db.name
  password = google_secret_manager_secret_version.db_password.secret_data
}


# ------------------------------------------------------------
# CLOUD RUN
# ------------------------------------------------------------

resource "google_cloud_run_v2_service" "f1_api" {
  name     = "f1-telemetry-api"
  location = "australia-southeast1"
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    containers {
      image = "australia-southeast1-docker.pkg.dev/PROJECT_ID/f1-stack/f1-telemetry-api:latest"

      env {
        name  = "DATABASE_HOST"
        value = "/cloudsql/${google_sql_database_instance.f1_db.connection_name}"
      }
      env {
        name  = "DATABASE_USER"
        value = var.db_username
      }
      env {
        name  = "DATABASE_PASSWORD"
        value = google_secret_manager_secret_version.db_password.secret_data
      }
      env {
        name  = "DATABASE_NAME"
        value = google_sql_database.f1_database.name
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }
  }
}

# ------------------------------------------------------------
# IAM
# ------------------------------------------------------------

resource "google_project_iam_member" "cloudrun_sql" {
  project = "PROJECT_ID"
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:PROJECT_NUMBER-compute@developer.gserviceaccount.com"
}

resource "google_secret_manager_secret_iam_member" "cloudrun_secret" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:PROJECT_NUMBER-compute@developer.gserviceaccount.com"
}