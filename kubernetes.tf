################################################################################
# Contains all resources deployed in the EKS cluster
################################################################################

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name
    ]
  }
}

resource "kubernetes_namespace" "pool" {
  metadata {
    name = "pool"
    labels = {
      name = "pool"
    }
  }
}

resource "kubernetes_ingress_class_v1" "alb" {
  metadata {
    name = "alb"
    # namespace = "pool"
    labels = {
      "app.kubernetes.io/name" = "LoadBalancerController"
    }
  }

  spec {
    controller = "eks.amazonaws.com/alb"
  }
}

resource "kubernetes_ingress_v1" "ingress-ms1" {
  metadata {
    name      = "ingress-ms1"
    namespace = "pool"
    annotations = {
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "service-ms1"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_account" "pool-sa" {
  metadata {
    name      = "pool-sa"
    namespace = kubernetes_namespace.pool.metadata[0].name
  }
}

################################################################################
# Microservice-1
################################################################################
resource "kubernetes_deployment" "deployment-ms1" {
  depends_on = [kubernetes_deployment.deployment-ms2]

  metadata {
    name      = "deployment-ms1"
    namespace = "pool"
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "app-ms1"
      }
    }
    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "app-ms1"
        }
      }
      spec {
        container {
          image             = "${aws_ecr_repository.pool-ms1.repository_url}:latest"
          name              = "app-ms1"
          image_pull_policy = "Always"

          port {
            container_port = 8000
          }

          resources {
            requests = {
              cpu = "0.5"
            }
          }
        }

        # Next two blocks used for ARM64 instances. Docs: https://docs.aws.amazon.com/eks/latest/userguide/set-builtin-node-pools.html
        node_selector = {
          "karpenter.sh/nodepool" = "system"
        }
        toleration {
          key      = "CriticalAddonsOnly"
          operator = "Exists"
        }
      }
    }
  }
}

resource "kubernetes_service" "service-ms1" {
  metadata {
    name      = "service-ms1"
    namespace = "pool"
  }

  spec {
    port {
      port        = 80
      target_port = 8000
      protocol    = "TCP"
    }
    type = "NodePort"
    selector = {
      "app.kubernetes.io/name" = "app-ms1"
    }
  }
}

################################################################################
# Microservice-2
################################################################################
resource "kubernetes_deployment" "deployment-ms2" {
  depends_on = [aws_eks_pod_identity_association.pool, kubernetes_service_account.pool-sa, null_resource.delay_for_iam_propagation]

  metadata {
    name      = "deployment-ms2"
    namespace = "pool"
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "app-ms2"
      }
    }
    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "app-ms2"
        }
      }
      spec {
        container {
          image             = "${aws_ecr_repository.pool-ms2.repository_url}:latest"
          name              = "app-ms2"
          image_pull_policy = "Always"

          port {
            container_port = 8000
          }

          env {
            name  = "DB_SECRET_ARN"
            value = aws_rds_cluster.pooldb.master_user_secret[0].secret_arn # For dev we're passing the secret ARN as env variable; In prod, use k8s secrets
          }
          env {
            name  = "AWS_REGION"
            value = local.region
          }
          env {
            name  = "DB_HOST"
            value = aws_rds_cluster.pooldb.endpoint
          }
        }

        # Next two blocks used for ARM64 instances. Docs: https://docs.aws.amazon.com/eks/latest/userguide/set-builtin-node-pools.html
        node_selector = {
          "karpenter.sh/nodepool" = "system"
        }
        toleration {
          key      = "CriticalAddonsOnly"
          operator = "Exists"
        }

        service_account_name            = kubernetes_service_account.pool-sa.metadata[0].name
        automount_service_account_token = true
      }
    }
  }
}

resource "kubernetes_service" "service-ms2" {
  metadata {
    name      = "service-ms2"
    namespace = "pool"
  }

  spec {
    port {
      port        = 80
      target_port = 8000
      protocol    = "TCP"
    }
    type = "NodePort"
    selector = {
      "app.kubernetes.io/name" = "app-ms2"
    }
  }
}
