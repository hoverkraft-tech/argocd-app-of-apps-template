---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: __APP_NAME__-review # Will be updated by deploy workflow
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
    argocd.argoproj.io/application-repository: __APP_NAME__
    argocd.argoproj.io/deployment-id: ""
    argocd.argoproj.io/environment: "review"
    notifications.argoproj.io/subscribe.on-sync-operation-change.slack: applications
    notifications.argoproj.io/subscribe.on-sync-operation-change.github-dispatch: ""
  labels:
    layer: applications
    service: __APP_NAME__
    environment: dev
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  destination:
    namespace: __APP_NAME__-review # Will be updated by deploy workflow
    server: <url-cluster-dev>
  syncPolicy:
    syncOptions:
      - CreateNamespace=false
      - ServerSideApply=true
      - SkipDryRunOnMissingResource=true
    automated:
      prune: true
      selfHeal: true
  sources:
    - repoURL: ghcr.io/<your-org>/__APP_NAME__/charts/application
      targetRevision: "" # Will be updated by deploy workflow
      chart: __APP_NAME__
      plugin:
        name: hoverkraft-deployment
        env:
          # set the following to "1" if this is an argocd multi-sources application
          - name: ARGOCD_MULTI_SOURCES
            value: "1"
          - name: HOVERKRAFT_DEPLOYMENT_ID
            value: "" # Will be updated by deploy workflow
    - repoURL: ghcr.io/<your-org>/__APP_NAME__/charts/application
      targetRevision: "" # Will be updated by deploy workflow
      chart: __APP_NAME__
      helm:
        values: |
          ingress:
            enabled: true
            className: "traefik"
            annotations:
              cert-manager.io/cluster-issuer: letsencrypt
            hosts:
              - host: __APP_NAME__-review.<your-domain> # Will be updated by deploy workflow
                paths:
                  - path: /
                    pathType: ImplementationSpecific
            tls:
              - secretName: __APP_NAME__-tls
                hosts:
                  - __APP_NAME__-review.<your-domain> # Will be updated by deploy workflow