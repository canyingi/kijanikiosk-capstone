variable "kubeconfig_path" {
  description = "Path to the kubeconfig that can reach Minikube"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "kubeconfig context to use (guards against applying to the wrong cluster)"
  type        = string
  default     = "minikube"
}

variable "environments" {
  description = "One entry per environment. To add an environment, add an entry here instead of copying resources."
  type = map(object({
    namespace       = string
    quota_cpu       = string
    quota_memory    = string
    limit_cpu       = string
    limit_memory    = string
    max_pods        = string
  }))
  default = {
    staging = {
      namespace       = "kijani-staging"
      quota_cpu       = "500m"
      quota_memory    = "512Mi"
      limit_cpu       = "1"
      limit_memory    = "1Gi"
      max_pods        = "6"
    }
    production = {
      namespace       = "default"
      quota_cpu       = "1"
      quota_memory    = "1Gi"
      limit_cpu       = "2"
      limit_memory    = "2Gi"
      max_pods        = "10"
    }
  }
}
