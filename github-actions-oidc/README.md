# GitHub Actions OIDC Bootstrap

Terraform configuration for the GitHub Actions AWS authentication layer.

This folder manages:

* GitHub OIDC provider
* GitHub Actions IAM role
* Terraform plan role
* Terraform apply role

This infrastructure is managed separately from the main infrastructure so it remains available when `infrastructure/` is destroyed.
