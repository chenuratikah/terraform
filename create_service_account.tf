# This example shows how to create a service account and provide GCS & BQ access to it.
# It also shows how to create service account key & secrets
# Common variable such as project-id, env and such are declared in variables.tf

resource "google_service_account" "my_sa" {
  account_id   = "my-sa" # The service account will be created as my-sa@project-id.iam.gserviceaccount.com
  display_name = "Service Account for fun"
  project      = var.project
}

# Provide jobUser access to BQ
resource "google_project_iam_member" "my_sa_bq_jobuser" {
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.my_sa.email}"
  project = var.project
}

# Provide objectAdmin access to GCS
resource "google_project_iam_member" "my_sa_storage_write" {
  provider = google-beta
  role     = "roles/storage.objectAdmin"
  member   = "serviceAccount:${google_service_account.my_sa.email}"
  project  = var.project

}

# Create SA private key & secret
resource "google_service_account_key" "my_sa_key" {
  service_account_id = google_service_account.my_sa.name
}

resource "google_secret_manager_secret" "my_sa_secret" {
  secret_id = "${google_service_account.my_sa.account_id}"

  replication {
    automatic = true
  }
  project = var.project
}

resource "google_secret_manager_secret_version" "my_sa_secret_version" {
  secret = google_secret_manager_secret.my_sa.id

  secret_data = google_service_account_key.my_sa.private_key
}
