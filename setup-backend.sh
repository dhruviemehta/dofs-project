#!/bin/bash

# Setup script for Terraform backend
# This script creates the S3 bucket and DynamoDB table for Terraform state management

set -e

echo "🚀 Setting up Terraform Backend for DOFS"
echo "========================================"

# Configuration
PROJECT_NAME=${PROJECT_NAME:-"dofs"}
ENVIRONMENT=${ENVIRONMENT:-"dev"}
AWS_REGION=${AWS_REGION:-"ap-south-1"}

echo "📋 Configuration:"
echo "  Project: $PROJECT_NAME"
echo "  Environment: $ENVIRONMENT"
echo "  Region: $AWS_REGION"
echo ""

# Check if we're in the right directory and navigate to terraform
if [ -f "terraform/backend-setup.tf" ]; then
    echo "📁 Changing to terraform directory..."
    cd terraform
elif [ -f "backend-setup.tf" ]; then
    echo "📁 Already in terraform directory..."
else
    echo "❌ Error: backend-setup.tf not found!"
    echo "Current directory: $(pwd)"
    echo "Looking for terraform/backend-setup.tf or backend-setup.tf"
    echo "Files in current directory:"
    ls -la
    if [ -d "terraform" ]; then
        echo "Files in terraform directory:"
        ls -la terraform/
    fi
    exit 1
fi

# Verify we have the configuration files
if [ ! -f "backend-setup.tf" ]; then
    echo "❌ Error: backend-setup.tf not found in $(pwd)!"
    exit 1
fi

echo "✅ Found configuration files in $(pwd)"

# Step 1: Initialize Terraform without backend
echo "1️⃣ Initializing Terraform (local state)..."
terraform init

# Step 2: Create backend resources
echo "2️⃣ Creating S3 bucket and DynamoDB table..."
terraform apply -auto-approve \
  -var="project_name=$PROJECT_NAME" \
  -var="environment=$ENVIRONMENT" \
  -var="aws_region=$AWS_REGION" \
  -target="aws_s3_bucket.terraform_state" \
  -target="aws_s3_bucket_versioning.terraform_state" \
  -target="aws_s3_bucket_server_side_encryption_configuration.terraform_state" \
  -target="aws_s3_bucket_public_access_block.terraform_state" \
  -target="aws_dynamodb_table.terraform_locks" \
  -target="random_id.bucket_suffix"

# Step 3: Get bucket name
echo "3️⃣ Getting bucket name..."
BUCKET_NAME=$(terraform output -raw terraform_state_bucket)
echo "✅ Bucket created: $BUCKET_NAME"

# Step 4: Create backend config file
echo "4️⃣ Creating backend configuration..."
cat > backend.hcl <<EOF
bucket         = "$BUCKET_NAME"
key            = "terraform.tfstate"
region         = "$AWS_REGION"
encrypt        = true
dynamodb_table = "dofs-terraform-locks"
EOF

echo "✅ Backend config created: backend.hcl"

# Step 5: Update backend.tf to uncomment the backend block
echo "5️⃣ Updating backend configuration..."
if grep -q "# backend \"s3\"" backend.tf; then
    # Uncomment the backend block
    sed -i.bak 's/# backend "s3" {/backend "s3" {/' backend.tf
    sed -i.bak 's/#   bucket/  bucket/' backend.tf
    sed -i.bak 's/#   key/  key/' backend.tf
    sed -i.bak 's/#   region/  region/' backend.tf
    sed -i.bak 's/#   encrypt/  encrypt/' backend.tf
    sed -i.bak 's/#   dynamodb_table/  dynamodb_table/' backend.tf
    sed -i.bak 's/# }/}/' backend.tf
    echo "✅ Backend block uncommented in backend.tf"
fi

# Step 6: Reconfigure Terraform with remote backend
echo "6️⃣ Migrating to remote backend..."
terraform init -backend-config=backend.hcl -migrate-state

echo ""
echo "🎉 Backend setup complete!"
echo "========================="
echo "✅ S3 Bucket: $BUCKET_NAME"
echo "✅ DynamoDB Table: dofs-terraform-locks"
echo "✅ State migrated to remote backend"
echo ""
echo "Now you can run the full infrastructure deployment:"
echo "  terraform plan -var=\"project_name=$PROJECT_NAME\" -var=\"environment=$ENVIRONMENT\" -var=\"aws_region=$AWS_REGION\""
echo "  terraform apply -var=\"project_name=$PROJECT_NAME\" -var=\"environment=$ENVIRONMENT\" -var=\"aws_region=$AWS_REGION\""
echo ""
echo "🔒 Your Terraform state is now stored securely in S3 with DynamoDB locking!"

# Step 2: Create backend resources
echo "2️⃣ Creating S3 bucket and DynamoDB table..."
terraform apply -auto-approve \
  -var="project_name=$PROJECT_NAME" \
  -var="environment=$ENVIRONMENT" \
  -var="aws_region=$AWS_REGION" \
  -target="aws_s3_bucket.terraform_state" \
  -target="aws_s3_bucket_versioning.terraform_state" \
  -target="aws_s3_bucket_server_side_encryption_configuration.terraform_state" \
  -target="aws_s3_bucket_public_access_block.terraform_state" \
  -target="aws_dynamodb_table.terraform_locks" \
  -target="random_id.bucket_suffix"

# Step 3: Get bucket name
echo "3️⃣ Getting bucket name..."
BUCKET_NAME=$(terraform output -raw terraform_state_bucket)
echo "✅ Bucket created: $BUCKET_NAME"

# Step 4: Create backend config file
echo "4️⃣ Creating backend configuration..."
cat > backend.hcl <<EOF
bucket         = "$BUCKET_NAME"
key            = "terraform.tfstate"
region         = "$AWS_REGION"
encrypt        = true
dynamodb_table = "dofs-terraform-locks"
EOF

echo "✅ Backend config created: backend.hcl"

# Step 5: Update backend.tf to uncomment the backend block
echo "5️⃣ Updating backend configuration..."
if grep -q "# backend \"s3\"" backend.tf; then
    # Uncomment the backend block
    sed -i 's/# backend "s3" {/backend "s3" {/' backend.tf
    sed -i 's/#   bucket/    bucket/' backend.tf
    sed -i 's/#   key/    key/' backend.tf
    sed -i 's/#   region/    region/' backend.tf
    sed -i 's/#   encrypt/    encrypt/' backend.tf
    sed -i 's/#   dynamodb_table/    dynamodb_table/' backend.tf
    sed -i 's/# }/  }/' backend.tf
    echo "✅ Backend block uncommented in backend.tf"
fi

# Step 6: Reconfigure Terraform with remote backend
echo "6️⃣ Migrating to remote backend..."
terraform init -backend-config=backend.hcl -migrate-state

echo ""
echo "🎉 Backend setup complete!"
echo "========================="
echo "✅ S3 Bucket: $BUCKET_NAME"
echo "✅ DynamoDB Table: dofs-terraform-locks"
echo "✅ State migrated to remote backend"
echo ""
echo "Now you can run the full infrastructure deployment:"
echo "  terraform plan -var=\"project_name=$PROJECT_NAME\" -var=\"environment=$ENVIRONMENT\" -var=\"aws_region=$AWS_REGION\""
echo "  terraform apply -var=\"project_name=$PROJECT_NAME\" -var=\"environment=$ENVIRONMENT\" -var=\"aws_region=$AWS_REGION\""
echo ""
echo "🔒 Your Terraform state is now stored securely in S3 with DynamoDB locking!"