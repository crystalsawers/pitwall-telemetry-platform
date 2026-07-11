# ------------------------------------------------------------
# ARTIFACT REGISTRY
# ------------------------------------------------------------

resource "google_artifact_registry_repository" "f1_repo" {
  location      = "australia-southeast1"
  repository_id = "f1-stack-tf"
  description   = "Docker repository for F1 telemetry stack"
  format        = "DOCKER"

  docker_config {
    immutable_tags = false
  }
}

resource "google_artifact_registry_repository_iam_member" "cloudbuild_writer" {
  project    = "YOUR_PROJECT_ID"
  location   = "australia-southeast1"
  repository = google_artifact_registry_repository.f1_repo.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

# ------------------------------------------------------------
# CLOUD BUILD TRIGGER (GitHub push)
# ------------------------------------------------------------

# Use this command before applying: 
# terraform import google_cloudbuild_trigger.f1_build projects/project-ID/locations/global/triggers/4d946a66-129c-4875-af48-f14696817c03

resource "google_cloudbuild_trigger" "f1_build" {
  name = "f1-telemetry-build"

  github {
    owner = "your-github-username"
    name  = "f1-telemetry-app"
    push {
      branch = "^main$"
    }
  }

  filename        = "cloudbuild.yaml"
  service_account = "projects/PROJECT_ID/serviceAccounts/PROJECT_NUMBER-compute@developer.gserviceaccount.com"

  depends_on = [
    google_artifact_registry_repository.f1_repo,
    google_artifact_registry_repository_iam_member.cloudbuild_writer
  ]
}