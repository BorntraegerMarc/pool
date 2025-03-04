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

resource "kubernetes_namespace" "game-2048" {
  metadata {
    name = "game-2048"
    labels = {
      name = "game-2048"
    }
  }
}

resource "kubernetes_deployment" "deployment-2048" {
  metadata {
    name      = "deployment-2048"
    namespace = "game-2048"
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "app-2048"
      }
    }
    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "app-2048"
        }
      }
      spec {
        container {
          image             = "public.ecr.aws/l6m2t8p7/docker-2048:latest"
          name              = "app-2048"
          image_pull_policy = "Always"

          port {
            container_port = 80
          }

          resources {
            requests = {
              cpu = "0.5"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "service-2048" {
  metadata {
    name      = "service-2048"
    namespace = "game-2048"
  }

  spec {
    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
    type = "NodePort"
    selector = {
      "app.kubernetes.io/name" = "app-2048"
    }
  }
}

resource "kubernetes_ingress_class_v1" "alb" {
  metadata {
    name = "alb"
    # namespace = "game-2048"
    labels = {
      "app.kubernetes.io/name" = "LoadBalancerController"
    }
  }

  spec {
    controller = "eks.amazonaws.com/alb"
  }
}

resource "kubernetes_ingress_v1" "ingress-2048" {
  metadata {
    name      = "ingress-2048"
    namespace = "game-2048"
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
              name = "service-2048"
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
