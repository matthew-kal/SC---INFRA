# SurgiCalm API - GCP Infrastructure

This repository contains the Infrastructure as Code (IaC) for the SurgiCalm API backend, written in Terraform. It defines a secure, scalable, and serverless architecture on Google Cloud Platform (GCP) designed to support the SurgiCalm mobile application.

---

## Architecture Overview

The infrastructure is designed around a core principle of serverless computing and security through private networking. A public-facing Cloud Run service hosts the Django application, which communicates securely with a private Cloud SQL database through a dedicated VPC Connector. All sensitive information is managed by Secret Manager, and media files are stored in a Cloud Storage bucket.


### Core Components

* **Compute**: **Google Cloud Run** provides a fully managed, serverless environment to run the containerized Django application, automatically scaling based on traffic.
* **Database**: **Google Cloud SQL for MySQL** offers a managed relational database instance. It is configured with a **private IP address**, ensuring it is completely isolated from the public internet.
* **Storage**: **Google Cloud Storage (GCS)** is used for durable and scalable storage of media files and other static assets.
* **Networking**: A **Custom Virtual Private Cloud (VPC)** creates an isolated network for the resources. A **VPC Peering** connection and a **VPC Access Connector** work together to provide a secure, private communication channel between Cloud Run and Cloud SQL.
* **Security**: **Google Secret Manager** securely stores and manages all sensitive data, such as database passwords and API keys. **Identity and Access Management (IAM)** roles are used to grant fine-grained permissions to services.
* **Automation**: **Google Cloud Scheduler** is used to run a daily cron job that securely invokes an API endpoint for periodic tasks.

---
## Project Variables (`variables.tf`)

This file defines the input variables for the entire Terraform configuration. This practice makes the infrastructure code reusable and allows for easy configuration without modifying the core logic. It serves as the single source for project-wide settings like the project ID and region.

### GCP Project ID

* **Variable**: `gcp_project_id`
* **Description**: The GCP project ID to deploy resources into. This is a required variable with no default, meaning its value must be provided when you run Terraform.

### GCP Region

* **Variable**: `gcp_region`
* **Description**: The GCP region for resources. This variable has a default value of `us-east4` (N. Virginia), so it does not need to be specified unless you intend to deploy the infrastructure to a different region.

---
## Provider Configuration (`provider.tf`)

This file tells Terraform how to communicate with the necessary cloud and helper APIs. A "provider" is a plugin that acts as a translator, converting the declarative Terraform code you write into specific API calls that the target platform, like Google Cloud, can understand.

### Terraform Core Configuration

* **Block**: `terraform { ... }`

This block configures Terraform's core requirements. You've declared that the project needs the `google` and `random` providers. The version constraints (e.g., `~> 5.10`) are a crucial best practice for stability, as they prevent automatic updates to new major versions that could contain breaking changes.

### Google Provider Configuration

* **Block**: `provider "google"`

This block configures the Google provider itself. It tells the provider which project and default region to operate in for all subsequent resources, using the values supplied from your `variables.tf` file.

---
## API Enablement (`apis.tf`)

This file is responsible for enabling the necessary APIs for your project. By default, a new Google Cloud project has most APIs turned off as a security precaution to prevent accidental use and billing. This configuration programmatically "flips the on switch" for each service you intend to use, which is a prerequisite for creating any resources.

### Project Service Configuration

* **Resource**: `google_project_service`

This resource manages a service API on a project. Instead of creating a separate resource block for each API, your configuration efficiently uses a `for_each` loop. This makes the code cleaner and easier to manage. The file enables the following critical APIs:

* **run.googleapis.com**: The Cloud Run API, required to create and manage your serverless service.
* **sqladmin.googleapis.com**: The Cloud SQL Admin API, required to provision and manage your database instance.
* **secretmanager.googleapis.com**: The Secret Manager API, for storing and accessing your secrets.
* **artifactregistry.googleapis.com**: The Artifact Registry API, for managing your Docker image repository.
* **cloudbuild.googleapis.com**: The Cloud Build API, which will be used for your CI/CD pipeline.
* **vpcaccess.googleapis.com**: The Serverless VPC Access API, required to create the connector that links Cloud Run to your VPC.
* **servicenetworking.googleapis.com**: The Service Networking API, required to establish the private connection between your VPC and Google's internal services.
* **iam.googleapis.com**: The Identity and Access Management (IAM) API, needed to manage roles and permissions.
* **cloudscheduler.googleapis.com**: The Cloud Scheduler API, required to create your cron job.

---
## Secrets Management (`secrets.tf`)

This file defines the secure storage for all of your application's sensitive data, such as passwords and API keys. Using Google Secret Manager is a critical security practice that ensures secrets are never hardcoded into your source code.

### Random Value Generation

* **Resources**: `random_password`, `random_string`

These helper resources from the `random` provider are not GCP resources. Their purpose is to generate strong, cryptographically random values directly within Terraform's memory during the planning and applying phase. These generated values are then passed to other resources without being displayed on the screen.

### Secret Container

* **Resource**: `google_secret_manager_secret`

This resource creates a "container" for a secret in Secret Manager. Think of it as creating a named, empty vault. It holds the metadata for the secret (like its name, e.g., `db-password`) and its access policies, but it does not hold the sensitive value itself.

### Secret Version

* **Resource**: `google_secret_manager_secret_version`

This resource stores the actual sensitive value inside a secret container. The `secret_data` attribute securely takes the value generated by the `random` resources and stores it as a new "version" within the corresponding secret. This practice is highly secure, as the secret value is managed entirely by Terraform and the GCP API without being exposed.

---
## Networking (`network.tf`)

This file builds the secure network foundation for the entire application. Instead of using the default GCP network, a custom Virtual Private Cloud (VPC) is created to provide a private, isolated environment. This ensures that sensitive resources, particularly the database, are not exposed to the public internet and can only be accessed through controlled pathways.

### Virtual Private Cloud (VPC)

* **Resource**: `google_compute_network`
* **Name**: `serverless-vpc`

This resource creates a new private network within your GCP project. The configuration `auto_create_subnetworks = false` is a deliberate security choice that gives you full control over the network's topology, preventing default subnets from being created in every GCP region.

### Private IP Range for Services

* **Resource**: `google_compute_global_address`
* **Name**: `private-ip-for-services`

This resource reserves a dedicated internal IP address range. Its `purpose` is explicitly set to `VPC_PEERING`, which means this block of IPs is reserved exclusively for creating a private connection to Google's internal network where managed services like Cloud SQL reside.

### VPC Peering Connection

* **Resource**: `google_service_networking_connection`

This is the key to enabling private database access. Think of this as building a **private, secure hallway** between your `serverless-vpc` and Google's separate, secure network that hosts the Cloud SQL service. This resource establishes that peering connection, using the IP range reserved in the previous step. It is this private link that allows a Cloud SQL instance to be provisioned without a public IP address.

### Serverless VPC Access Connector

* **Resource**: `google_vpc_access_connector`
* **Name**: `serverless-connector`

This resource acts as the **secure doorway** or bridge for your serverless application. Since Cloud Run runs in a separate, Google-managed environment outside of your VPC, it needs this connector to send traffic *inward* into your private network. The connector is configured with its own small IP range (`10.8.0.0/28`) and is the component that allows your public-facing Cloud Run service to securely communicate with your private Cloud SQL database.

---
## Storage (`storage.tf`)

This file defines a Google Cloud Storage (GCS) bucket. In a web application, GCS is the standard and most efficient way to handle user-uploaded media files and other static assets, as it separates file storage from the application's compute layer.

### Media Storage Bucket

* **Resource**: `google_storage_bucket`
* **Name**: Dynamically generated using your project ID (e.g., `your-project-id-surgicalm-media`)

This resource creates a new GCS bucket for storing your application's files. The name is generated dynamically to ensure it is globally unique. A key configuration is `uniform_bucket_level_access = true`, which simplifies permissions. Instead of managing access for every single file, this setting allows all permissions to be controlled at the bucket level using IAM roles. The specific role granting your Cloud Run service access to this bucket is defined in `cloud_run.tf`.

---
## Database (`database.tf`)

This file provisions your fully managed MySQL database instance using Google Cloud SQL. It defines the instance itself, the logical database within it, and the user that your application will use to connect.

### Cloud SQL Instance

* **Resource**: `google_sql_database_instance`
* **Name**: `sc-db-instance-prod`

This is the main resource that creates the Cloud SQL instance. Key configurations include:
* **`database_version`**: Specifies that the instance will run `MYSQL_8_0`.
* **`settings.tier`**: Sets the machine size to `db-n1-standard-1`.
* **`ip_configuration`**: This block is critical for security, as it attaches the instance to your private `serverless-vpc`, ensuring it has no public IP address.
* **`deletion_protection = true`**: This is an important safety feature that prevents the database from being accidentally deleted.

### Logical Database

* **Resource**: `google_sql_database`
* **Name**: `sc-db`

This resource creates the logical database named `sc-db` *inside* the instance you just provisioned. This is the database that your Django application will connect to and where all your tables will be created.

### Database User

* **Resource**: `google_sql_user`
* **Name**: `sc_user`

This creates the MySQL user `sc_user` that your application will use to authenticate with the database. Its `password` is securely set using the value generated by the `random_password` resource, avoiding any hardcoded credentials.

---
## Application Layer (`cloud_run.tf`)

This is the most complex file, defining your application's compute environment, its unique identity within GCP, the specific permissions it needs to operate, and its runtime configuration.

### Artifact Registry Repository

* **Resource**: `google_artifact_registry_repository`
* **Name**: `surgicalm-api-repo`

This resource creates a private repository specifically for `DOCKER` images. This is the secure location where your built application images are stored and from where Cloud Run will pull them for deployment.

### Service Account

* **Resource**: `google_service_account`
* **Name**: `surgicalm-api-sa`

This creates a dedicated service account, which acts as a non-human identity for your application. Your Cloud Run service will authenticate as this service account when it needs to access other GCP resources. This is a fundamental security practice, as it allows you to grant permissions to the application itself, rather than using personal user credentials.

### IAM Roles and Policies

These resources grant your application the specific permissions it needs to function, following the principle of least privilege.

* **Public Access Policy**
    * **Resource**: `google_cloud_run_v2_service_iam_policy`
    * This policy makes your service publicly accessible. It attaches an IAM policy directly to the Cloud Run service, granting the `roles/run.invoker` role to the special member `allUsers`, which means "anyone on the internet" can call the service's URL.

* **Service Account Permissions**
    * These resources grant specific roles to the `surgicalm-api-sa` service account, allowing it to access other parts of your infrastructure.

| Role Granted | Justification |
| :--- | :--- |
| `roles/secretmanager.secretAccessor` | Allows the application to read the values of secrets (like the database password and Django secret key) from Secret Manager. |
| `roles/cloudsql.client` | Allows the application to connect to the private Cloud SQL instance through the VPC connector. |
| `roles/storage.objectAdmin` | Grants the application full control over files within the specific GCS media bucket, allowing it to handle user uploads. |

### Cloud Run Service

* **Resource**: `google_cloud_run_v2_service`
* **Name**: `surgicalm-api`

This is the main resource that defines your serverless application. The `template` block within it serves as a blueprint for each new revision of your service.
* **Service Account**: The `surgicalm-api-sa` service account is assigned to the service, giving it the permissions defined above.
* **Networking**: The service is connected to your private network via the `vpc_access` block, which references the `serverless-connector`. The `egress = "ALL_TRAFFIC"` setting forces all outbound traffic from the container to go through the VPC, ensuring it can reach the database's private IP.
* **Container Image**: The `image` attribute specifies the full path to the Docker image to run, dynamically constructing the name from your project variables and the Artifact Registry repository.
* **Resources**: `limits` are set to cap the resources for each instance at 1 CPU and 512Mi of memory.
* **Environment Variables**: The `env` block configures the runtime environment inside the container. It passes crucial settings to your Django application, such as the database host's private IP address. Sensitive values like the `DATABASE_PASSWORD` are injected securely using a `value_source` block that references Secret Manager directly. This is a highly secure practice as the secret values are never exposed in the service configuration or Terraform state.

---
## Automation (`scheduler.tf`)

This file defines an automated, recurring task for your application using Google Cloud Scheduler. This is a fully managed cron job service that allows you to trigger your API endpoints on a schedule.

### Daily User Data Refresh Job

* **Resource**: `google_cloud_scheduler_job`
* **Name**: `daily-user-data-refresh`

This resource creates a job that runs at 2:00 AM in the `America/New_York` time zone, as defined by the `schedule` and `time_zone` attributes.

The job is configured with an `http_target` to send a `POST` request to an endpoint in your API. A key aspect of this configuration is its security model. Instead of using a static, long-lived API key, the job uses an `oidc_token`.

An **OIDC Token** is a secure, short-lived credential that proves the request's identity. Think of it as a **signed, single-use ticket to an event**. The scheduler job gets this ticket from Google, which is cryptographically signed and identifies the request as coming from your application's service account. Your Cloud Run service automatically knows how to verify this signature, ensuring that only this specific, authorized job can trigger the endpoint.

---
## Outputs (`outputs.tf`)

This file defines values that Terraform will print to your console after a successful deployment. Outputs are a convenient way to expose important, often dynamically generated, information about your infrastructure for easy access.

* **`cloud_run_service_url`**: This output displays the main public URL of your Cloud Run service. This is the primary endpoint for your API.
* **`cloud_sql_instance_name`**: This provides the unique connection name for your database instance. This specific name is required when you need to connect to the database from your local machine using the Cloud SQL Auth Proxy for tasks like running migrations.
* **`media_bucket_name`**: This displays the name of your Google Cloud Storage bucket, which is useful for referencing in application code or for manual inspection in the console.

---