# Configure AWS CLI with iam user's access key
aws configure 

# Verify identity
aws sts get-caller-identity 

# Manually create s3 bucket for terraform state file
aws s3 mb s3://amzn-s3-demo-bucket

# Init terraform backend 
terraform init

# Format
terraform fmt --recursive 
