# CSYE 6225 Assignment 03 - Demo Guide

## 📋 Demo Environment Information

### AWS Demo Account
- **Account ID**: 506160144092
- **Email**: lian.wei+demo@northeastern.edu
- **Region**: us-east-1 (N. Virginia)
- **Console**: https://console.aws.amazon.com/

### GCP Demo Project
- **Project ID**: weihong-demo
- **Region**: us-east1
- **Console**: https://console.cloud.google.com/

### GitHub Repository
- **Organization**: https://github.com/DBAAcsye6225/tf-infra
- **Fork**: https://github.com/DBAA21/tf-infra

---

## 🎯 Demo Checklist (10 Points)

### 1. AWS Organization & IAM Setup (1 point)

**Steps:**
1. Log in to Root account → AWS Organizations
2. Show 3 accounts: Root (DBAA), Dev, Demo
3. Switch to Demo account → IAM → User groups
4. Show `csye6225-ta` group with `ReadOnlyAccess` policy
5. Show IAM users: Devanshu_Rajesh_Chicholikar, Sohan_Patil
6. Verify group membership and no access keys

---

### 2. Shell Script (2 points)

**Terminal Commands:**
```bash
cd ~/webapp
ls -la scripts/setup.sh
head -30 scripts/setup.sh
```

**Key Points to Show:**
- Shebang line: `#!/bin/bash`
- Error handling: `set -e`
- English comments
- Idempotent checks (if ! id -u, CREATE DATABASE IF NOT EXISTS)

---

### 3. CLI Configuration (1 point)

**Terminal Commands:**
```bash
# AWS CLI
aws --version
aws configure list --profile dev
aws configure list --profile demo
aws configure list  # Should show <not set>

# GCP CLI
gcloud --version
gcloud config configurations list
```

**Expected:**
- Both CLIs installed
- Dev and Demo profiles/configurations exist
- NO default profile/configuration

---

### 4. Infrastructure as Code - Repository & Structure (1 point)

**GitHub Navigation:**
1. Show repository root: README.md, .gitignore, .github/workflows/
2. Show aws/ directory: main.tf, variables.tf, outputs.tf, providers.tf
3. Show gcp/ directory: main.tf, variables.tf, outputs.tf, providers.tf
4. Open main.tf files → Show variable usage (no hard-coded values)

---

### 5. AWS Networking via Terraform (2 points)

**AWS Console (Demo Account):**

**Important:** Switch region to **US East (N. Virginia)** first!

1. **VPC**: VPC → Your VPCs → Show `csye6225-vpc-demo` (10.1.0.0/16)
2. **IGW**: Internet Gateways → Show attached gateway
3. **Subnets**: Show 6 subnets
   - 3 public (10.1.1-3.0/24) in us-east-1a/b/c
   - 3 private (10.1.4-6.0/24) in us-east-1a/b/c
4. **Route Tables**: Show 2 route tables
   - Public: 0.0.0.0/0 → IGW, 3 subnet associations
   - Private: Local only, 3 subnet associations

**Terminal Commands:**
```bash
cd ~/tf-infra/aws
cat terraform.tfvars  # Show aws_profile = "demo"
terraform output
```

---

### 6. GCP Networking via Terraform (2 points)

**GCP Console (Demo Project):**

**Important:** Switch to **weihong-demo** project first!

1. **VPC**: VPC network → VPC networks → Show `csye6225-vpc-demo`
2. **Subnets**: Show 6 subnets (10.2.1-6.0/24) in us-east1
3. **Routes**: VPC → Routes → Show 0.0.0.0/0 → default-internet-gateway
4. **Firewall**: VPC → Firewall rules
   - Show: `allow-web` (ports 22, 80, 443, 8080)
   - Show: `deny-all` (priority 65534)

**Terminal Commands:**
```bash
cd ~/tf-infra/gcp
cat terraform.tfvars  # Show project_id = "weihong-demo"
terraform output
```

---

### 7. GitHub Branch Protection & CI (1 point)

**GitHub Navigation:**

1. **Branch Protection**: Settings → Branches
   - Show protection rules for `main` branch
   - Highlight: PR required, status checks, up-to-date, no bypass

2. **CI Workflow**: 
   - Show `.github/workflows/terraform-check.yml`
   - Navigate to Pull requests → Show closed/merged PR
   - Point out: CI checks passed (terraform fmt, terraform validate)

---

## 🔧 Quick Commands Reference

### Switch Between Environments

**AWS:**
```bash
cd ~/tf-infra/aws
# For Demo: ensure terraform.tfvars has aws_profile = "demo"
# For Dev: cp terraform.tfvars.dev terraform.tfvars
```

**GCP:**
```bash
cd ~/tf-infra/gcp
gcloud config configurations activate demo  # or dev
```

### Verify Deployments

**AWS:**
```bash
aws ec2 describe-vpcs --profile demo --region us-east-1 \
  --filters "Name=tag:Name,Values=csye6225-vpc-demo"
```

**GCP:**
```bash
gcloud compute networks list --project=weihong-demo
```

---

## 📊 Deployed Resources Summary

| Platform | Environment | Resources | VPC CIDR | Status |
|----------|-------------|-----------|----------|--------|
| AWS | Dev | 16 | 10.0.0.0/16 | ✅ Ready |
| AWS | Demo | 16 | 10.1.0.0/16 | ✅ Ready |
| GCP | Dev | 10 | 10.1.x.x/24 | ✅ Ready |
| GCP | Demo | 10 | 10.2.x.x/24 | ✅ Ready |

**Total: 52 cloud resources successfully deployed**

---

## 🎓 Key Concepts to Remember

1. **Principle of Least Privilege**: TAs get read-only access
2. **Infrastructure as Code**: All resources defined in version-controlled Terraform
3. **Parameterization**: No hard-coded values, supports multiple deployments
4. **Idempotency**: Scripts and Terraform can run multiple times safely
5. **Separation of Concerns**: Separate directories for AWS and GCP
6. **CI/CD**: Automated validation on every pull request

---

## ✅ Pre-Demo Final Check

Run before demo:
```bash
# Verify all configurations
cd ~/tf-infra
git status  # Should be clean

cd aws && terraform plan  # Should show 0 changes
cd ../gcp && terraform plan  # Should show 0 changes

# Verify CLI tools
aws sts get-caller-identity --profile demo
gcloud config get-value project  # Should be weihong-demo
```

---

## 📝 Notes

- All development done in fork (DBAA21/tf-infra)
- Merged to organization repo (DBAAcsye6225/tf-infra) via PR
- TAs added as collaborators with appropriate permissions
- No credentials committed to repository
```

---

## 🤖 给 Agent 的 Prompt
```
Add the demo guide document to the tf-infra repository and push all changes.

## Task 0: Create Feature Branch (IMPORTANT - Do this FIRST) 1. Navigate to tf-infra: `cd ~/tf-infra` 2. Ensure on main: `git checkout main` 3. Pull latest: `git pull origin main` 4. Create feature branch: `git checkout -b feature/add-demo-guide` 5. Verify branch: `git branch`

## Task 1: Create Demo Guide
1. Navigate to tf-infra: `cd ~/tf-infra`
2. Create DEMO_GUIDE.md file with the content provided
3. Verify file created: `cat DEMO_GUIDE.md | head -20`

## Task 2: Update AWS Configuration for Demo
1. Ensure AWS terraform.tfvars uses demo profile:
```bash
   cd ~/tf-infra/aws
   cat terraform.tfvars  # Should show aws_profile = "demo"
```

## Task 3: Commit and Push Changes
1. Return to root: `cd ~/tf-infra`
2. Check status: `git status`
3. Add all changes: `git add .`
4. Commit: `git commit -m "docs: add demo presentation guide and finalize configurations"`
5. Push to fork: `git push origin feature/add-demo-guide`

## Task 4: Sync Fork with Upstream
1. Fetch upstream: `git fetch upstream`
2. Check if there are upstream changes: `git log HEAD..upstream/main --oneline`
3. If there are changes, merge: `git merge upstream/main`
4. Push to fork: `git push origin main`

## Task 5: Provide PR Information
After pushing, provide:
1. Confirmation that branch was pushed
2. The URL to create Pull Request from:
   - From: DBAA21/tf-infra:feature/add-demo-guide
   - To: DBAAcsye6225/tf-infra:main

## Expected Output
Provide:
1. Confirmation that DEMO_GUIDE.md was created
2. Commit hash
3. Confirmation that changes were pushed
4. Current sync status with upstream

After this, the repository will be ready for submission with complete documentation for the demo presentation.
```
