# nullplatform-configuration-aws

Terraform configuration to deploy nullplatform on AWS with EKS (Elastic Kubernetes Service). This setup supports both **EKS standard mode** and **EKS Auto Mode**.

## EKS Mode Configuration

The cluster can be configured in two modes by setting the `use_auto_mode` variable in `infrastructure/main.tf`:

```hcl
module "eks" {
  source                  = "git::https://github.com/nullplatform/tofu-modules.git//infrastructure/aws/eksautomode?ref=v1.12.4"
  aws_subnets_private_ids = module.vpc.private_subnets
  aws_vpc_vpc_id          = module.vpc.vpc_id
  name                    = local.cluster_name

  # Variable to configure EKS mode:
  # - false (default): Standard EKS mode - you manage node groups, scaling, and compute
  # - true: EKS Auto Mode - AWS automatically manages compute, scaling, and upgrades
  use_auto_mode           = true

  depends_on              = [module.vpc]
}
```

### Standard Mode (default)
- Manual management of node groups and scaling policies
- Full control over compute resources
- Requires explicit configuration of node groups

### Auto Mode
- AWS automatically provisions and scales compute resources
- Simplified cluster management
- Automatic node upgrades and patching

## Project Structure

```
.
├── common.tfvars.example          # Shared variables across all modules
├── infrastructure/                 # AWS infrastructure (VPC, EKS, DNS, etc.)
├── nullplatform/                   # nullplatform organization configuration
└── nullplatform-bindings/          # Repository and cloud provider bindings
```

## Modules

### 1. Infrastructure (`infrastructure/`)

Provisions the AWS infrastructure required for nullplatform:

| Component | Description |
|-----------|-------------|
| **VPC** | Virtual Private Cloud with public/private subnets |
| **EKS** | Kubernetes cluster (standard or auto mode) |
| **DNS** | Route53 hosted zones and ACM certificates |
| **ALB Controller** | AWS Load Balancer Controller for Kubernetes |
| **Ingress** | Ingress configuration with SSL/TLS |
| **Agent IAM** | IAM roles for the nullplatform agent |
| **Agent** | nullplatform agent deployment |
| **Prometheus** | Optional monitoring stack |

### 2. Nullplatform (`nullplatform/`)

Configures nullplatform organization-level resources:

| Component | Description |
|-----------|-------------|
| **Account** | nullplatform account configuration |
| **Scope Definition** | Service path and scope configuration |
| **Dimensions** | Environment dimensions (development, staging, production) |
| **Metadata Specification** | Application metadata schema |
| **Approval Policies** | Deployment approval policies (e.g., PCI compliance) |

### 3. Nullplatform Bindings (`nullplatform-bindings/`)

Configures integrations and bindings:

| Component | Description |
|-----------|-------------|
| **Code Repository** | GitHub integration |
| **Asset Repository** | ECR container registry configuration |
| **Cloud Provider** | AWS cloud provider configuration |
| **Channel Association** | Links scope definitions with agents |
| **Monitoring Provider** | Metrics integration for observability |

## Prerequisites

- Terraform/OpenTofu >= 1.0
- AWS CLI configured with appropriate credentials
- nullplatform API key
- GitHub App installation (for code repository integration)

## Usage

### 1. Configure shared variables

```bash
cp common.tfvars.example common.tfvars
```

Edit `common.tfvars`:
```hcl
nrn        = "organization=your-org:account=your-account"
np_api_key = "your-api-key"

tags_selectors = {
  "environment" : "development"
}
```

### 2. Deploy Infrastructure

```bash
cd infrastructure/aws
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

terraform init
terraform plan -var-file="../../common.tfvars" -var-file="terraform.tfvars"
terraform apply -var-file="../../common.tfvars" -var-file="terraform.tfvars"
```

### 3. Configure Nullplatform

```bash
cd ../../nullplatform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

terraform init
terraform plan -var-file="../common.tfvars" -var-file="terraform.tfvars"
terraform apply -var-file="../common.tfvars" -var-file="terraform.tfvars"
```

### 4. Configure Bindings

```bash
cd ../nullplatform-bindings
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

terraform init
terraform plan -var-file="../common.tfvars" -var-file="terraform.tfvars"
terraform apply -var-file="../common.tfvars" -var-file="terraform.tfvars"
```

## Key Variables

### Common Variables

| Variable | Description |
|----------|-------------|
| `nrn` | Nullplatform Resource Name (e.g., `organization=xxx:account=xxx`) |
| `np_api_key` | API key for nullplatform authentication |
| `tags_selectors` | Tags to link channels with agents |

### Infrastructure Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region for deployment | - |
| `aws_profile` | AWS CLI profile name | - |
| `organization` | Organization name in nullplatform | - |
| `cluster_name` | Name of the EKS cluster | - |
| `domain_name` | Base DNS domain for the cluster | - |
| `vpc` | VPC configuration (CIDR, subnets, AZs) | - |
| `install_prometheus` | Enable Prometheus monitoring | `true` |

### Bindings Variables

| Variable | Description |
|----------|-------------|
| `github_organization` | GitHub organization name |
| `github_installation_id` | GitHub App installation ID |
| `dimensions` | Metadata dimensions for observability |

## Remote State

Each module uses Terraform remote state. Configure the backend in `backend.tf` for each module according to your state management strategy (S3, Terraform Cloud, etc.).

<!-- BEGIN_TF_DOCS -->

<!-- END_TF_DOCS -->