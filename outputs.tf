################################################################################
# Cluster
################################################################################

output "eks_cluster_endpoint" {
  description = "Endpoint Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "web_api_hostname" {
  description = "Web API Hostname"
  value       = "Load Balancer takes some extra time to provision. Please check your endpoint for Web API under https://${local.region}.console.aws.amazon.com/ec2/home?LoadBalancers:v=3&region=${local.region}#LoadBalancers:v=3;"
}
