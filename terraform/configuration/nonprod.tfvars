environment  = "nonprod"
location     = "West US"
app_name     = "myapp"
image_tag    = "latest"

# Placeholder values for local/terraform plan only — override in CI from secret variables.
database_connection_string = "Server=sql-myapp-nonprod.database.windows.net;Database=myapp;User Id=sqladmin;Password=REPLACE_ME;Encrypt=true"
api_key                    = "REPLACE_ME"
datadog_api_key            = "REPLACE_ME"

log_retention_days = 7
min_replicas       = 0
max_replicas       = 1
