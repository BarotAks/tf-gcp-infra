# Terraform Infrastructure Setup for Google Cloud Platform (GCP)

This repository contains Terraform configuration files for setting up networking infrastructure on Google Cloud Platform (GCP).

## Installation and Setup

### 1. Install Google Cloud SDK (gcloud CLI)

Follow the [official documentation](https://cloud.google.com/sdk/docs/install) to download and install the Google Cloud SDK.

After installation, authenticate with your Google Cloud account:

```bash
gcloud auth login
```

### 2. Install Terraform

Follow the instructions provided [here](https://learn.hashicorp.com/tutorials/terraform/install-cli) to install Terraform for your operating system.

Verify the installation by running:

```bash
terraform version
```
### 3. Enable Google Cloud APIs

Before using the Terraform configuration, you need to enable the following Google Cloud APIs for your project. Below is a non-exhaustive list of APIs that can come in handy :

```bash
gcloud services enable compute.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable servicenetworking.googleapis.com
```

## Downloading Repository and Running Terraform Commands

### 1. Clone this Repository

Clone this repository to your local machine using the following command:

```bash
git clone <repository_url>
cd <repository_name>
```

### 2. Initialize Terraform

Navigate to the directory containing the Terraform configuration files and initialize Terraform:

```bash
terraform init
```

### 3. Plan Terraform Configuration

Generate and view an execution plan before applying the Terraform configuration:

```bash
terraform plan
```

### 4. Apply Terraform Configuration

Apply the Terraform configuration to create the networking infrastructure:

```bash
terraform apply
```

Follow the prompts to confirm the changes. Once completed, Terraform will provision the specified resources on GCP.

### 5. Destroy Terraform Resources
   
If you want to destroy the provisioned resources and clean up the environment, you can use the following command:

```bash
terraform destroy
```
Confirm the action by typing yes when prompted. This will delete all resources provisioned by Terraform.

