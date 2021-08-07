# This example shows how to create external tables located in a GCS bucket.
# The source data comes in parquet and CSV format
# The tables are only needed in STG environment, hence, you'll see the usage of `count` with boolean.
# Common variable such as project-id, env and such are declared in variables.tf

variable parquet_files_gcs {
  default = {
    table_name   = { id = "table_name", gcs_path = "path/to/*.parquet" }
    # and more...

  }
}

variable csv_files_gcs {
  default = {
    table_name   = { id = "table_name", gcs_path = "path/to/*.csv" }
    # and more...
  }
}

# The service account specified somewhere else
variable my_sa_email {} # service-account-name@project-id.iam.gserviceaccount.com

# Optional, the label will show in the BQ table
# The keys can be anything. Eg: tech & lob (line of business)
locals {
  my_labels = {
    env  = var.env
    tech = "stuff_1"
    lob  = "stuff_2"
  }
}

# Create a dataset in BQ
resource "google_bigquery_dataset" "my_dataset" {
  count         = var.env == "stg" ? 1 : 0 # Specify to ONLY create the table in stg. If env == stg, then 1.
  dataset_id    = "MY_DATASET"
  friendly_name = "MY_FRIENDLY_NAME"
  description   = "Provide your description"
  location      = var.region
  project       = var.project
  labels        = local.my_labels
  
  # Provide access to SA and individual using email respectively
  access {
    role          = "WRITER"
    user_by_email = var.my_sa_email
  }

  access {
    role          = "READER"
    user_by_email = "someone@gmail.com"
  }
  
  # Further info on dynamic blocks : https://www.terraform.io/docs/language/expressions/dynamic-blocks.html
  dynamic access {
    for_each = local.default_dataset_group_access
    content {
      role          = access.key
      special_group = access.value
    }
  }
}


# Create external tables in BQ for parquet files
resource "google_bigquery_table" "my_ext_tables_parquet" {
  dataset_id  = google_bigquery_dataset.my_dataset[0].dataset_id # Follows resource name in line 35
  for_each    = var.env == "stg" ? { for my_parquet in var.parquet_files_gcs : my_parquet.id => my_parquet } : {}
  table_id    = each.key
  description = (each.value).gcs_path

  external_data_configuration {
    autodetect            = true
    source_format         = "PARQUET"
    ignore_unknown_values = true
    source_uris = [
      "gs://${var.project}-my-gcs/${(each.value).gcs_path}" # Assume GCS bucket is called `project-id-my-gcs`
    ]
  }

  # Merge with common labels provided & add personalised labels if needed.
  labels = merge(local.my_labels,
    {
      pic  = "some-name"
      type = "external-table"
    }
  )

  project = var.project
}


resource "google_bigquery_table" "my_ext_tables_csv" {
  dataset_id  = google_bigquery_dataset.my_dataset[0].dataset_id
  for_each    = var.env == "stg" ? { for my_csv in var.csv_files_gcs : my_csv.id => my_csv } : {}
  table_id    = each.key
  description = "EXTERNAL TABLE"

  external_data_configuration {
    autodetect    = true
    source_format = "CSV"

    csv_options {
      quote             = ""
      skip_leading_rows = 1
    }

    source_uris = [
      "gs://${var.project}-my-gcs/${(each.value).gcs_path}"

    ]
  }

  labels = merge(local.my_labels,
    {
      pic  = "someone"
      type = "external-table"
    }
  )

  project = var.project
}

# Provide access to specific user only on specific dataset
# Providing dataViewer & jobUser will allow the user to access AND query the tables.
resource "google_bigquery_dataset_iam_member" "some_user_email" {
  count      = var.env == "stg" ? 1 : 0
  dataset_id = google_bigquery_dataset.my_dataset[0].dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "user:someone@gmail.com"
  project    = var.project
}

resource "google_project_iam_member" "some_user_jobcreate_email" {
  count   = var.env == "stg" ? 1 : 0
  role    = "roles/bigquery.jobUser"
  member  = "user:someone@gmail.com"
  project = var.project
}
