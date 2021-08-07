
# This example shows how to create a GCS bucket on specific env ONLY.
# This example also shows how to create a customised role and add permission using existing and customised role to a service account and users.
# Common variable such as project-id, env and such are declared in variables.tf

# Create GCS only on stg env
resource "google_storage_bucket" "my_gcs" {
  count              = var.env == "stg" ? 1 : 0
  name               = "${var.project}-my-gcs"
  location           = "asia-southeast1"
  force_destroy      = false
  project            = var.project
  storage_class      = "STANDARD"
  bucket_policy_only = true

  lifecycle {
    prevent_destroy = false
  }

  logging {
    log_bucket = google_storage_bucket.access_logs.name
  }

}

# Create a customised role to access GCS bucket
resource "google_project_iam_custom_role" "my_gcs_get_buckets" {
  project     = var.project
  role_id     = "MyGCSGetBuckets"
  title       = "Customised role for Get Buckets"
  description = "Allow get buckets"
  permissions = ["storage.objects.list", "storage.buckets.list",
  "resourcemanager.projects.get", "storage.buckets.get"]
}

# Provide objectAdmin access to SA
resource "google_storage_bucket_iam_member" "my_gcs_object_access" {
  count    = var.env == "stg" ? 1 : 0
  provider = google-beta
  bucket   = google_storage_bucket.my_gcs[0].name
  role     = "roles/storage.objectAdmin"
  member   = "serviceAccount:${var.my_sa_email.email}"
}

#Provide SA with customised role
resource "google_storage_bucket_iam_member" "my_gcs_bucket_access" {
  count  = var.env == "stg" ? 1 : 0
  bucket = google_storage_bucket.my_gcs[0].name
  role   = google_project_iam_custom_role.my_gcs_get_buckets.id # Take from customised role resource name
  member = "serviceAccount:${var.my_sa_email.email}"

}

# Provide specific user as objectViewer and customised role respectively
resource "google_storage_bucket_iam_member" "my_gcs_user_email_access" {
  count    = var.env == "stg" ? 1 : 0
  provider = google-beta
  bucket   = google_storage_bucket.my_gcs[0].name
  role     = "roles/storage.objectViewer"
  member   = "user:someone@gmail.com"

}

resource "google_storage_bucket_iam_member" "my_gcs_bucket_user_access" {
  count  = var.env == "stg" ? 1 : 0
  bucket = google_storage_bucket.my_gcs[0].name
  role   = google_project_iam_custom_role.my_gcs_get_buckets.id # Take from customised role resource name
  member = "user:someone@gmail.com"

}
