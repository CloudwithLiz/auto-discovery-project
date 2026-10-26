# Auto-Discovery Project

Infrastructure as Code that builds a self-healing AWS platform for the Pet Adoption (PetClinic) app and deploys it to staging and production automatically.

Application servers run in Auto Scaling Groups, so their IP addresses change as servers are added or replaced. An Ansible control node checks AWS every minute, finds every running server, and deploys the latest Docker image from Nexus to it. No one maintains a host list by hand.



## Overview

The project has two main parts:

1. **CI/CD pipeline** — how code gets tested, scanned, and deployed
2. **AWS infrastructure** — where the application actually runs

## CI/CD Pipeline

| Component | Purpose |
|---|---|
| Terraform IaC | Provisions all AWS infrastructure from code |
| Jenkins | Orchestrates the build and deploy pipeline |
| IaC GitHub Repo | Stores the Terraform infrastructure code |
| App GitHub Repo | Stores the application source code |
| Checkov | Scans Terraform code for security misconfigurations before deployment |
| OWASP ZAP | Runs dynamic security tests against the running application |
| Trivy | Scans container images for known vulnerabilities |
| Vault | Stores and controls access to secrets (credentials, API keys) |
| Nexus | Stores build artifacts such as Docker images |
| SonarQube | Analyzes code quality and flags bugs or code smells |
| New Relic | Monitors application performance |
| Slack |Sends pipeline notifications|

**Flow:** GitHub repos → Jenkins pulls code → Checkov/Trivy/ZAP scan it → Vault supplies secrets → Jenkins deploys through the Bastion Host into the private network.

## AWS Network Layout

- **Region** eu-west-2
- The VPC spans **two Availability Zones** for redundancy
- Each AZ has a **public subnet** and a **private subnet**

### Public Subnets (internet-facing)

- **Bastion Host ASG** — secure entry point for administrative access into the private network
- **NAT Gateway** — lets private subnet resources reach the internet (e.g. for updates) without being directly reachable from it
- **Stage ALB / Prod ALB** — load balancers routing traffic to the application
- **SonarQube / Nexus** — supporting tools placed here for pipeline access

### Private Subnets (internal only)

- **Docker Host ASGs** (Stage and Prod, across both AZs) — run the containerized application
- **RDS databases** (Stage and Prod) — store application data
- **Ansible** — configures and manages the Docker hosts

### State Management

- **S3 Bucket** — stores the Terraform state file
- **DynamoDB** — locks that state so only one person can apply changes at a time
- Both feed back into Terraform, completing the infrastructure-as-code loop








## Architecture

At a high level, the project separates public-facing services from application workloads:

- Public subnets host configured internet-facing resources, including load balancers and supporting access infrastructure.
- Private subnets host application instances and database resources where configured.
- Application Load Balancers distribute incoming traffic to the staging and production environments.
- Auto Scaling Groups manage application instances and support instance replacement and scaling.
- An Auto-Discovery script queries AWS for current running instances and updates the Ansible inventory.
- Ansible uses the updated inventory to target the current application instances during deployment.
- Jenkins coordinates the CI/CD pipeline and integrates with the GitHub repositories.
- SonarQube analyses application source code, OWASP Dependency-Check scans dependencies, Trivy scans Docker images, and Checkov scans Terraform configurations.
- Nexus stores application build artifacts for subsequent deployment.
- Vault manages configured secrets, including database credentials.
- Amazon RDS MySQL provides database services.
- Amazon Route 53 and ACM support DNS and HTTPS for configured endpoints.
- New Relic and Slack provide monitoring and pipeline notifications where configured.

## Repository Structure

The project uses separate GitHub repositories for infrastructure and application code. The exact directory structure depends on the repository.

```text
.
.
|-- main.tf                  # Root Terraform configuration
|-- provider.tf              # AWS provider and Terraform backend configuration
|-- variables.tf             # Input variable definitions
|-- outputs.tf               # Terraform outputs
-- jenkins/                  # Jenkins and Vault infrastructure
|-- Jenkinsfile              # Jenkins CI/CD pipeline
|-- create-s3-bucket.sh      # Create remote state resources
|-- delete-s3-bucket.sh      # Delete remote state resources
|-- modules/                 # Reusable Terraform modules
|   |-- vpc/                 # VPC, subnets, gateways, and routing
|   |-- bastion/             # Bastion host and access configuration
|   |-- database/            # Application database resources
|   |-- nexus/               # Nexus infrastructure
|   |-- ansible/             # Ansible configuration and deployment
|   |-- sonarqube/           # SonarQube infrastructure
|   |-- stage-docker/        # Staging environment resources
|   `-- prod-docker/         # Production environment resources
`-- README.md                # Project documentation
```


## Terraform State

The Terraform configuration uses an S3 remote backend for state storage and DynamoDB for state locking where configured.

- **S3 bucket:** Stores the Terraform state file.
- **DynamoDB table:** Prevents concurrent Terraform operations from modifying the same state.
- **State separation:** Separate state keys can be used for different infrastructure stacks or environments.
- **State protection:** S3 versioning and encryption help protect stored state.


## Prerequisites

Before applying this project, make sure you have:

- Terraform installed at a compatible version.
- AWS CLI installed and configured with the correct AWS profile.
- Access to the AWS region configured in Terraform.
- The required S3 backend bucket and DynamoDB lock table created, if using a remote backend.
- Required AWS permissions for EC2, VPC, IAM, S3, DynamoDB, Auto Scaling, Elastic Load Balancing, RDS, Route 53, ACM, and other services used by the configuration.
- Access to the infrastructure and application GitHub repositories.
- Jenkins configured with the required plugins, credentials, and webhook integrations.
- Ansible and Docker configured for the deployment workflow.
- Maven and a compatible Java version for building the application.
- Valid Route 53 hosted zone and ACM certificate configuration for HTTPS endpoints.
- Required integrations configured for SonarQube, Nexus, Vault, New Relic, and Slack.

## Usage

Initialize and validate the Terraform configuration from the appropriate infrastructure directory:

```bash
terraform init
terraform fmt -check
terraform validate
```

Review the planned infrastructure changes:

```bash
terraform plan
```

Apply the infrastructure after reviewing the plan:

```bash
terraform apply
```

Run these commands from the correct Terraform working directory and use the required variables, workspace, AWS profile, and region.

For application delivery, trigger the configured Jenkins pipeline through a GitHub webhook or manually from Jenkins. Review the pipeline results before promoting the application from staging to production.

## Auto-Discovery Workflow

The Auto-Discovery mechanism keeps the Ansible inventory updated as EC2 instances change.

The workflow is as follows:

1. A scheduled cron job runs the discovery script.
2. The script queries AWS for running instances in the configured Auto Scaling Groups.
3. It retrieves the current instance IP addresses.
4. It updates the relevant Ansible inventory file.
5. Ansible uses the refreshed inventory when a deployment or configuration playbook runs.

This reduces manual inventory maintenance and helps deployment automation target the current instances.


## Jenkins Pipeline

The Jenkins pipeline automates the application delivery workflow. Depending on the configured Jenkinsfile, the stages include:

- Checkout application source code from GitHub.
- Run SonarQube source-code analysis and quality-gate checks.
- Build the Java application using Maven.
- Scan third-party dependencies using OWASP Dependency-Check.
- Publish the build artifact to Nexus.
- Use Ansible to retrieve the artifact and coordinate Docker image creation.
- Scan the Docker image using Trivy.
- Deploy the application to the selected staging or production environment.
- Run Checkov scans in the infrastructure pipeline to identify Terraform configuration issues.
- Send Slack notifications for pipeline success or failure where configured.

The infrastructure pipeline uses Terraform to initialize, validate, plan, and apply infrastructure changes according to the configured approval process.

## Security

Security controls are applied across the infrastructure and CI/CD workflow:

- Private GitHub repositories and token-based authentication control source-code access.
- Checkov scans Terraform configurations for potential security misconfigurations.
- OWASP Dependency-Check identifies known vulnerabilities in third-party libraries.
- Trivy scans Docker images for known vulnerabilities.
- Security groups restrict network access according to the configured service requirements.
- Private subnets limit direct public exposure of application and database resources where configured.
- AWS Systems Manager supports managed access to eligible instances.
- Vault manages configured secrets, including database credentials.
- ACM certificates support HTTPS on configured endpoints.
- S3 versioning, encryption, and public-access blocking help protect Terraform state where enabled.

Security scanning helps identify potential issues, but findings must be reviewed and resolved according to the project's deployment policy.

## Monitoring and Notifications

New Relic is used where configured to monitor infrastructure and application performance. Slack notifications provide updates on Jenkins pipeline results.

For troubleshooting, review Jenkins console output, Auto Scaling Group activity, load-balancer target health, EC2 instance status, Ansible logs, Docker container logs, application logs, and New Relic telemetry.

## Cost Management

Cost-management practices include:

- Using appropriately sized EC2 instances and database resources.
- Configuring Auto Scaling Group capacity based on workload requirements.
- Reviewing AWS billing and Cost Explorer.
- Removing unused resources and temporary environments.
- Preserving shared resources required for Terraform state management.

Actual costs depend on the resources deployed, the AWS region, and usage.

## Cleanup

Before destroying infrastructure:

1. Confirm the AWS account, region, workspace, and Terraform backend.
2. Review the resources that will be removed.
3. Back up required application data and artifacts.
4. Identify shared resources that must remain, including state-storage resources.
5. Review the Terraform destroy plan or cleanup script.
6. Verify the resources removed from AWS.

**Warning:** Destroying infrastructure can cause application downtime and permanent data loss.

## Notes

- Review `terraform fmt -check`, `terraform validate`, and `terraform plan` before applying infrastructure changes.
- Keep credentials, private keys, tokens, and other sensitive information out of source control.
- Confirm that the Auto-Discovery script uses the correct AWS region, Auto Scaling Group identifiers, and Ansible inventory path.
- Inventory refresh and application deployment are separate operations unless explicitly connected in the automation.
- Verify the actual Terraform modules, Jenkins stages, and security settings before relying on them in production.


**Naming convention:** all resources created for this project are prefixed `Project2026-` followed by a descriptive name.


