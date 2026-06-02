---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: landing-page-review # Will be updated by deploy workflow
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
    argocd.argoproj.io/application-repository: landing-page
    argocd.argoproj.io/deployment-id: ""
    argocd.argoproj.io/environment: "review"
  labels:
    layer: applications
    service: landing-page
    environment: dev
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  destination:
    namespace: landing-page-review # Will be updated by deploy workflow
    server: <url cluster dev>
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
      - SkipDryRunOnMissingResource=true
    automated:
      prune: true
      selfHeal: true
  sources:
    - repoURL: ghcr.io/<your-org>/landing-page/charts/application
      targetRevision: "" # Will be updated by deploy workflow
      chart: landing-page
      helm:
        values: |
          ingress:
            enabled: true
            hosts:
              - host: landing-page-review.<user-xx>.hoverkraft.cloud # Will be updated by deploy workflow
                paths:
                  - path: /
                    pathType: ImplementationSpecific
