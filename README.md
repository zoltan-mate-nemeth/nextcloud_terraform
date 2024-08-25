# nextcloud_terraform

# Nextcloud Terraform Deployment

This repository contains Terraform configurations to deploy a Nextcloud instance on AWS.

## Getting Started

1. **Clone the repository:**
    ```bash
    git clone https://github.com/your_username/nextcloud_terraform.git
    cd nextcloud_terraform
    ```

2. **Configure your variables:**
    Edit the `terraform.tfvars` file with your AWS region, instance details, and SSH key path.

3. **Deploy the infrastructure:**
    ```bash
    terraform init
    terraform apply
    ```

4. **Access Nextcloud:**
    Once the deployment is complete, access your Nextcloud instance via the provided URL.

## Usage

- **Update infrastructure:** `terraform apply`
- **Destroy infrastructure:** `terraform destroy`

