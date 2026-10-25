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

**Flow:** GitHub repos → Jenkins pulls code → Checkov/Trivy/ZAP scan it → Vault supplies secrets → Jenkins deploys through the Bastion Host into the private network.

## AWS Network Layout

- **Region** contains one **VPC** (`172.16.0.0/16`)
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


**Naming convention:** all resources created for this project are prefixed `Aug2026-` followed by a descriptive name.

**Pending:** the VPC, public subnet, private subnet, and internet gateway references in `main.tf` are placeholders and need to be updated once the networking module (owned by another team member) is finalized.

