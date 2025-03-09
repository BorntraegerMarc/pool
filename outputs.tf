################################################################################
# Cluster
################################################################################

output "eks_cluster_endpoint" {
  description = "Endpoint Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "web_api_hostname" {
  description = "Web API Hostname"
  value       = length(kubernetes_ingress_v1.ingress-ms1.status[0].load_balancer[0].ingress) > 0 ? kubernetes_ingress_v1.ingress-ms1.status[0].load_balancer[0].ingress[0].hostname : "The Load Balancer takes more time to provision. Please check your endpoint for the Web API once the load balancer becomes available under https://${local.region}.console.aws.amazon.com/ec2/home?LoadBalancers:v=3&region=${local.region}#LoadBalancers:v=3;"
}
