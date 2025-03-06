################################################################################
# Cluster
################################################################################

output "eks_cluster_endpoint" {
  description = "Endpoint Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "web_api_hostname" {
  description = "Web API Hostname"
  value       = length(kubernetes_ingress_v1.ingress-ms1.status[0].load_balancer[0].ingress) > 0 ? kubernetes_ingress_v1.ingress-ms1.status[0].load_balancer[0].ingress[0].hostname : "empty"
}
