resource "helm_release" "argocd" {
  name             = "argocd"
  chart            = "${path.module}/charts/argo-cd.tgz"
  namespace        = "argocd"
  create_namespace = true

  set = [
    {
      name  = "server.service.type"
      value = "ClusterIP"
    },
    {
      name  = "server.ingress.enabled"
      value = "false"
    },
    {
      name  = "configs.params.server\\.insecure"
      value = "true"
    },
    {
      name  = "server.replicas"
      value = "1"
    },
    {
      name  = "repoServer.replicas"
      value = "1"
    },
    {
      name  = "controller.replicas"
      value = "1"
    }
  ]

}

resource "kubernetes_manifest" "task_api_application" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"

    metadata = {
      name      = "task-api"
      namespace = "argocd"
    }

    spec = {
      project = "default"

      source = {
        repoURL        = var.repo_url
        targetRevision = var.branch_name
        path           = "k8s-manifests"
      }

      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "default"
      }
    }
  }

  depends_on = [helm_release.argocd]
}