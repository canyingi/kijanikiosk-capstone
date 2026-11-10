# Infrastructure layer: what has to EXIST before anything can be configured or deployed.
#   - the kijani-staging namespace (production stays in the existing `default` namespace)
#   - a ResourceQuota + LimitRange in each namespace, so staging cannot use up production's share
# Settings INSIDE the namespaces (ConfigMaps, Secrets) are Ansible's job - see ADR-002.
# The receipt buckets are NOT here: they belong to the serverless stack - see ADR-004.

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.31" }
  }

  # Same MinIO remote state I set up in Week 4, with a new key for the capstone.
  backend "s3" {
    bucket                      = "kijanikiosk-tfstate"
    key                         = "capstone/terraform.tfstate"
    region                      = "us-east-1"
    endpoints                   = { s3 = "http://localhost:9000" }
    use_path_style              = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_lockfile                = true
  }
}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}

locals {
  # Namespaces Terraform must create. `default` already exists and is never created or destroyed here.
  created_namespaces = { for k, v in var.environments : k => v if v.namespace != "default" }
}

resource "kubernetes_namespace" "env" {
  for_each = local.created_namespaces

  metadata {
    name = each.value.namespace
    labels = {
      "app.kubernetes.io/part-of" = "kijanikiosk"
      "kijanikiosk.io/environment" = each.key
      "managed-by"                 = "terraform"
    }
  }
}

resource "kubernetes_resource_quota" "env" {
  for_each = var.environments

  metadata {
    name      = "kijanikiosk-quota"
    namespace = each.value.namespace
  }
  spec {
    hard = {
      "requests.cpu"    = each.value.quota_cpu
      "requests.memory" = each.value.quota_memory
      "limits.cpu"      = each.value.limit_cpu
      "limits.memory"   = each.value.limit_memory
      pods              = each.value.max_pods
    }
  }
  depends_on = [kubernetes_namespace.env]
}

# A container deployed without its own requests/limits still gets these defaults.
resource "kubernetes_limit_range" "env" {
  for_each = var.environments

  metadata {
    name      = "kijanikiosk-defaults"
    namespace = each.value.namespace
  }
  spec {
    limit {
      type            = "Container"
      default         = { cpu = "250m", memory = "256Mi" }
      default_request = { cpu = "100m", memory = "128Mi" }
    }
  }
  depends_on = [kubernetes_namespace.env]
}
