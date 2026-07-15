# ------------------------------------------------------------
# KUBERNETES PROVIDER
# ------------------------------------------------------------

data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.f1_cluster.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.f1_cluster.master_auth[0].cluster_ca_certificate)
}

# ------------------------------------------------------------
# FASTAPI DEPLOYMENT
# ------------------------------------------------------------

resource "kubernetes_deployment_v1" "fastapi" {
  metadata {
    name      = "fastapi-app"
    namespace = "default"
    labels = {
      app = "fastapi"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "fastapi"
      }
    }

    template {
      metadata {
        labels = {
          app = "fastapi"
        }
      }

      spec {
        container {
          name  = "cloudsql-proxy"
          image = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:latest"
          args  = ["--port=5432", google_sql_database_instance.f1_db.connection_name]

          resources {
            requests = {
              cpu    = "100m"
              memory = "64Mi"
            }
          }
        }

        container {
          name  = "fastapi"
          image = "australia-southeast1-docker.pkg.dev/project-1f40dd62-739c-473a-b20/f1-stack/f1-telemetry-api:latest"

          port {
            container_port = 8000
          }

          env {
            name  = "DATABASE_HOST"
            value = "localhost"
          }
          env {
            name  = "DATABASE_PORT"
            value = "5432"
          }
          env {
            name  = "DATABASE_NAME"
            value = google_sql_database.f1_database.name
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
            name  = "DATABASE_URL"
            value = "postgresql://${var.db_username}:${google_secret_manager_secret_version.db_password.secret_data}@localhost:5432/${google_sql_database.f1_database.name}"
          }

          resources {
            requests = {
              cpu    = "300m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }
      }
    }
  }
}

# ------------------------------------------------------------
# FASTAPI SERVICE
# ------------------------------------------------------------

resource "kubernetes_service_v1" "fastapi" {
  metadata {
    name      = "fastapi-app-service"
    namespace = "default"
  }

  spec {
    selector = {
      app = "fastapi"
    }

    port {
      name        = "http"
      port        = 8000
      target_port = 8000
    }

    type = "LoadBalancer"
  }
}

# ------------------------------------------------------------
# PROMETHEUS CONFIG
# ------------------------------------------------------------

resource "kubernetes_config_map_v1" "prometheus_config" {
  metadata {
    name      = "prometheus-config"
    namespace = "default"
  }

  data = {
    "prometheus.yml" = <<-EOF
      global:
        scrape_interval: 15s

      scrape_configs:
        - job_name: prometheus
          static_configs:
            - targets: ["localhost:9090"]

        - job_name: fastapi
          metrics_path: /metrics
          static_configs:
            - targets: ["fastapi-app-service:8000"]

          relabel_configs:
            - source_labels: [__address__]
              target_label: instance
            - target_label: job
              replacement: fastapi
    EOF
  }
}

# ------------------------------------------------------------
# PROMETHEUS DEPLOYMENT
# ------------------------------------------------------------

resource "kubernetes_deployment_v1" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = "default"
    labels = {
      monitoring = "prometheus"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        monitoring = "prometheus"
      }
    }

    template {
      metadata {
        labels = {
          monitoring = "prometheus"
        }
      }

      spec {
        container {
          name  = "prometheus"
          image = "prom/prometheus:latest"
          args  = ["--config.file=/etc/prometheus/prometheus.yml"]

          port {
            container_port = 9090
          }

          resources {
            requests = {
                cpu    = "200m"
                memory = "256Mi"
            }
            limits = {
                cpu    = "500m"
                memory = "512Mi"
            }
            }

          volume_mount {
            name       = "prometheus-config"
            mount_path = "/etc/prometheus/prometheus.yml"
            sub_path   = "prometheus.yml"
          }
        }

        volume {
          name = "prometheus-config"
          config_map {
            name = kubernetes_config_map_v1.prometheus_config.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [kubernetes_deployment_v1.fastapi]
}

# ------------------------------------------------------------
# PROMETHEUS SERVICE
# ------------------------------------------------------------

resource "kubernetes_service_v1" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = "default"
  }

  spec {
    selector = {
      monitoring = "prometheus"
    }

    port {
      name        = "http"
      port        = 9090
      target_port = 9090
    }

    type = "ClusterIP"
  }
}

# ------------------------------------------------------------
# GRAFANA SERVICE ACCOUNT
# ------------------------------------------------------------

resource "kubernetes_service_account_v1" "grafana" {
  metadata {
    name      = "grafana"
    namespace = "default"
  }
}

# ------------------------------------------------------------
# GRAFANA CONFIGMAPS
# ------------------------------------------------------------

resource "kubernetes_config_map_v1" "grafana_datasources" {
  metadata {
    name      = "grafana-datasources"
    namespace = "default"
  }

  data = {
    "datasources.yaml" = <<-EOF
      apiVersion: 1

      datasources:
        - name: Prometheus
          type: prometheus
          access: proxy
          url: http://prometheus:9090
          isDefault: true
          editable: false

        - name: Infinity
          type: yesoreyeram-infinity-datasource
          access: proxy
          editable: false
    EOF
  }
}

resource "kubernetes_config_map_v1" "grafana_dashboard_provider" {
  metadata {
    name      = "grafana-dashboard-provider"
    namespace = "default"
  }

  data = {
    "provider.yaml" = <<-EOF
      apiVersion: 1

      providers:
        - name: "f1-dashboards"
          orgId: 1
          folder: "F1 Dashboards"
          type: file
          disableDeletion: false
          editable: true
          options:
            path: /var/lib/grafana/dashboards
    EOF
  }
}

resource "kubernetes_config_map_v1" "grafana_dashboard_files" {
  metadata {
    name      = "grafana-dashboard-files"
    namespace = "default"
  }

  data = {
    "f1-telemetry-data.json"   = file("${path.module}/dashboards/f1-telemetry-data.json")
    "f1-telemetry-system.json" = file("${path.module}/dashboards/f1-telemetry-system.json")
  }
}

# ------------------------------------------------------------
# GRAFANA DEPLOYMENT
# ------------------------------------------------------------

resource "kubernetes_deployment_v1" "grafana" {
  metadata {
    name      = "grafana"
    namespace = "default"
    labels = {
      monitoring = "grafana"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        monitoring = "grafana"
      }
    }

    template {
      metadata {
        labels = {
          monitoring = "grafana"
        }
      }

      spec {
        service_account_name            = kubernetes_service_account_v1.grafana.metadata[0].name
        automount_service_account_token = false

        container {
          name  = "grafana"
          image = "grafana/grafana:latest"

          port {
            container_port = 3000
          }

          env {
            name  = "GF_PLUGINS_PREINSTALL"
            value = "yesoreyeram-infinity-datasource"
          }

          env {
            name  = "GF_SECURITY_ADMIN_USER"
            value = "admin"
          }

          env {
            name  = "GF_SECURITY_ADMIN_PASSWORD"
            value = var.grafana_password
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "300m"
              memory = "256Mi"
            }
          }

          volume_mount {
            name       = "grafana-datasources"
            mount_path = "/etc/grafana/provisioning/datasources"
          }

          volume_mount {
            name       = "grafana-dashboard-provider"
            mount_path = "/etc/grafana/provisioning/dashboards"
          }

          volume_mount {
            name       = "grafana-dashboards"
            mount_path = "/var/lib/grafana/dashboards"
          }
        }

        volume {
          name = "grafana-datasources"
          config_map {
            name = kubernetes_config_map_v1.grafana_datasources.metadata[0].name
          }
        }

        volume {
          name = "grafana-dashboard-provider"
          config_map {
            name = kubernetes_config_map_v1.grafana_dashboard_provider.metadata[0].name
          }
        }

        volume {
          name = "grafana-dashboards"
          config_map {
            name = kubernetes_config_map_v1.grafana_dashboard_files.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [kubernetes_deployment_v1.prometheus]
}

# ------------------------------------------------------------
# GRAFANA SERVICE (LoadBalancer)
# ------------------------------------------------------------

resource "kubernetes_service_v1" "grafana" {
  metadata {
    name      = "grafana-service"
    namespace = "default"
    labels = {
      monitoring = "grafana"
    }
  }

  spec {
    selector = {
      monitoring = "grafana"
    }

    port {
      port        = 3000
      target_port = 3000
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }
}