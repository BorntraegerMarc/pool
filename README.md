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

```bash
git clone https://github.com/BorntraegerMarc/pool.git
cd ./pool
```

Verify Docker is running:

```bash
docker ps
```

The demo app deploys the following VPC CIDR range: 10.0.0.0/16 Ensure you don't have a VPC with with this CIDR range in your target AWS account in the `us-east-1` region:

```bash
aws ec2 describe-vpcs --region us-east-1
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

Finished 🎉
