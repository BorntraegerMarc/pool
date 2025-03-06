# pool

# Setup

```
export AWS_ACCESS_KEY_ID=
```

```
export AWS_SECRET_ACCESS_KEY=
```

# To Document

Init:

- Validate correct AWS permissions
- Remote State?
- Terraform v1.3+ installed locally.
- an AWS account
- the AWS CLI v2.7.0/v1.24.0 or newer, installed and configured
- AWS IAM Authenticator
- kubectl v1.24.0 or newer
- Have Docker running locally
- Ensure you don't have other VPC with CIDR range 10.0.0.0/16 running
- Runs only on Linux/Mac - not Windows

New Init:

- Open Terminal / Console
- Signin AWS CLI
- git clone https://github.com/BorntraegerMarc/pool.git
- cd ./pool
- terraform init
- terraform apply -auto-approve
- See output: to view web app

If you want to interact with the EKS Node locally:
aws eks update-kubeconfig --region us-east-1 --name ex-pool

## Why deploy with Terraform?

While you could use kubectl or similar CLI-based tools to manage your Kubernetes resources, using Terraform has the following benefits:

Unified Workflow - If you are already provisioning Kubernetes clusters with Terraform, use the same configuration language to deploy your applications into your cluster.

Full Lifecycle Management - Terraform doesn't only create resources, it updates, and deletes tracked resources without requiring you to inspect the API to identify those resources.

Graph of Relationships - Terraform understands dependency relationships between resources. For example, if a Persistent Volume Claim claims space from a particular Persistent Volume, Terraform won't attempt to create the claim if it fails to create the volume.
