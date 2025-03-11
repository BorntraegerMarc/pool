# Pool Demo App Getting Started

# Setup Prerequisites

- This demo uses AWS resources to automatically deploy the demo app into a target AWS account. You need to an AWS account to use.
- Validate that you have sufficient AWS permissions in the target account.
- [Install Terraform v1.3+](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
- [Install AWS CLI v2.7.0/v1.24.0 or newer](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [Install Docker](https://docs.docker.com/engine/install/)
- Tested only on Mac/Linux - not Windows

# Installation

Start a console and [Setup the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html)

Ensure you don't have other VPC with CIDR range 10.0.0.0/16 in your target AWS account in the `us-east-1` region

```bash
git clone https://github.com/BorntraegerMarc/pool.git
cd ./pool
```

Verify Docker is running:

```bash
docker ps
```

Init Terraform:

```bash
terraform init
```

Apply Terraform scripts & start deployment:

```bash
terraform apply
```

The output should look something like this:

```bash
[...]
Apply complete! Resources: 90 added, 0 changed, 0 destroyed.

Outputs:

eks_cluster_endpoint = "..."
web_api_hostname = "The Load Balancer takes more time to provision. Please check your endpoint for the Web API once the load balancer becomes available under ..."
```

If you want to query/interact with the EKS Node locally:

```bash
aws eks update-kubeconfig --region us-east-1 --name ex-pool

kubectl get pods --all-namespaces
```

TODOs:

- Check load balancing between microservices

## Why deploy with Terraform?

While you could use kubectl or similar CLI-based tools to manage your Kubernetes resources, using Terraform has the following benefits:

Unified Workflow - If you are already provisioning Kubernetes clusters with Terraform, use the same configuration language to deploy your applications into your cluster.

Full Lifecycle Management - Terraform doesn't only create resources, it updates, and deletes tracked resources without requiring you to inspect the API to identify those resources.

Graph of Relationships - Terraform understands dependency relationships between resources. For example, if a Persistent Volume Claim claims space from a particular Persistent Volume, Terraform won't attempt to create the claim if it fails to create the volume.
