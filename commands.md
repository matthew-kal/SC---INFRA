### Terraform Commands ###

# Initializes your Terraform working directory.
# Downloads the necessary provider plugins and sets up the backend for storing your state file.
terraform init

# Creates an execution plan.
# Shows you which resources will be created, updated, or destroyed without actually making any changes.
terraform plan

# Executes the actions determined by the plan.
# This command actually creates, updates, or deletes your cloud resources.
terraform apply

### Google Cloud Commands ###

# Connects a local port to the Cloud SQL Prod DB 
# Needs the cloud-sql-proxy executeable 
./cloud-sql-proxy --port=3307 surgicalm:us-east4:sc-db-instance-prod

# Logs you, the user, into the gcloud command-line tool.
# This is for authenticating yourself to run gcloud commands directly in your terminal.
gcloud auth login

# Logs in and creates credentials for applications.
# Crucial for authenticating tools like Terraform. Use this to fix "invalid_grant" errors.
gcloud auth application-default login