# CSYE 6225 - Network Structures and Cloud Computing
## Infrastructure as Code (Terraform)

This repository contains Terraform configurations for provisioning cloud networking infrastructure on both AWS and GCP.

---

## 📁 Repository Structure
```
tf-infra/
├── README.md                    # This file
├── .gitignore                   # Git ignore rules for Terraform
├── .github/
│   └── workflows/
│       └── terraform-check.yml  # CI workflow for Terraform validation
├── aws/
│   ├── main.tf                  # AWS resource definitions
│   ├── variables.tf             # AWS input variables
│   ├── outputs.tf               # AWS output values
│   ├── providers.tf             # AWS provider configuration
│   └── terraform.tfvars         # AWS variable values (not committed)
└── gcp/
    ├── main.tf                  # GCP resource definitions
    ├── variables.tf             # GCP input variables
    ├── outputs.tf               # GCP output values
    ├── providers.tf             # GCP provider configuration
    └── terraform.tfvars         # GCP variable values (not committed)
```

---

## 🔧 Prerequisites

### Required Tools
- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [Google Cloud CLI (gcloud)](https://cloud.google.com/sdk/docs/install)

### AWS Setup
1. Configure AWS CLI with named profiles (do NOT use default):
```bash
   aws configure --profile dev
   aws configure --profile demo
```

2. Set your preferred region (e.g., `us-east-1`)

### GCP Setup
1. Configure gcloud CLI with named configurations (do NOT use default):
```bash
   gcloud config configurations create dev
   gcloud config set project 
   gcloud auth login
   
   gcloud config configurations create demo
   gcloud config set project 
   gcloud auth login
```

2. Set your preferred region and zone:
```bash
   gcloud config set compute/region us-east1
   gcloud config set compute/zone us-east1-b
```

---

## 🚀 Usage

### AWS Infrastructure Deployment

1. **Navigate to AWS directory:**
```bash
   cd aws/
```

2. **Create `terraform.tfvars` file:**
```hcl
   aws_region  = "us-east-1"
   aws_profile = "dev"  # or "demo"
   vpc_name    = "csye6225-vpc-dev"
   vpc_cidr    = "10.0.0.0/16"
```

3. **Initialize Terraform:**
```bash
   terraform init
```

4. **Review planned changes:**
```bash
   terraform plan
```

5. **Apply configuration:**
```bash
   terraform apply
```

6. **Destroy resources (when needed):**
```bash
   terraform destroy
```

### GCP Infrastructure Deployment

1. **Navigate to GCP directory:**
```bash
   cd gcp/
```

2. **Authenticate with Application Default Credentials:**
```bash
   gcloud auth application-default login
   gcloud auth application-default set-quota-project 
```

3. **Create `terraform.tfvars` file:**
```hcl
   project_id = "your-dev-project-id"
   region     = "us-east1"
   vpc_name   = "csye6225-vpc-dev"
```

4. **Initialize Terraform:**
```bash
   terraform init
```

5. **Review planned changes:**
```bash
   terraform plan
```

6. **Apply configuration:**
```bash
   terraform apply
```

7. **Destroy resources (when needed):**
```bash
   terraform destroy
```

---

## 📦 AWS Resources Created

- **1 VPC** with custom CIDR block
- **1 Internet Gateway** attached to VPC
- **6 Subnets** (3 public + 3 private) across 3 availability zones
- **2 Route Tables** (1 public + 1 private)
- **1 Public Route** (0.0.0.0/0 → Internet Gateway)
- **6 Route Table Associations**

---

## 📦 GCP Resources Created

- **1 VPC Network** (custom subnet mode)
- **6 Subnets** (3 public + 3 private) across 3 zones
- **1 Route** (0.0.0.0/0 → default internet gateway)
- **2 Firewall Rules** (allow web traffic + deny all)

---

## 🔐 Security Best Practices

- **No hard-coded values** - All configurable values use variables
- **Named profiles/configurations** - Never use default AWS/GCP profiles
- **Parameterized naming** - Supports multiple deployments in same account
- **Branch protection** - All changes require pull requests and CI checks
- **`.gitignore` configured** - Sensitive files excluded from version control

---

## 🔄 CI/CD Workflow

GitHub Actions automatically runs on every pull request:
- ✅ `terraform fmt -check` - Validates code formatting
- ✅ `terraform validate` - Validates configuration syntax

Pull requests can only be merged after all checks pass.

## SSL Certificate Import (DEMO Environment)

The demo environment uses a third-party SSL certificate (ZeroSSL) imported into AWS Certificate Manager.

### Import Command

```bash
aws acm import-certificate \
   --certificate fileb://certificate.crt \
   --private-key fileb://demo.dbaa.me.key \
   --certificate-chain fileb://ca_bundle.crt \
   --profile demo \
   --region us-east-1
```

The certificate ARN returned by this command must be set in `terraform.tfvars` as `certificate_arn`.

---

## 📚 Additional Resources

- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)
- [GCP VPC Documentation](https://cloud.google.com/vpc/docs)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)

---

## 👨‍💻 Author

**Weihong Lian**  
Northeastern University - CSYE 6225  
Network Structures and Cloud Computing

---

## 📄 License

This project is created for educational purposes as part of CSYE 6225 coursework.
```

---
