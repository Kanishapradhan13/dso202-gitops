<!-- README.md - DSO202 Assignment 4 - overview -->
# dso202-gitops

GitOps delivery of the three-tier Task Tracker (Postgres, Node.js backend, nginx frontend) from Assignments 1-3, using Argo CD.

- **What this repository is:** the single source of truth for a local kind cluster (`dso202-gitops`). Argo CD watches this repo and reconciles the cluster to it; nothing is applied by hand after the bootstrap step.
- **Environments:** `dev` follows `main` with automated sync, prune and self-heal. `staging` is pinned to a release tag (`v1.0.0`) and is promoted manually.
- **Credentials:** only as Sealed Secrets (Sealed Secrets 2.20.0 / 0.40.0). No plaintext secret or sealing key is ever committed.
- **Versions:** Argo CD v3.5.6, argocd CLI v3.5.6, kubeseal v0.40.0, images `sarojsanyasi/dso202-{frontend,backend,db}:1.0`.

## Layout

```
cluster/        kind cluster config
bootstrap/      Argo CD install (kustomize) and the root app-of-apps (applied by hand, once)
argocd/         AppProjects and Applications (delivered by the root app)
platform/       per-environment namespace, quota, limits, RBAC, SealedSecrets
charts/         the tasktracker Helm chart
environments/   per-environment values
docs/           report.md (objectives, steps, challenges, Q1-Q6), evidence.md (terminal screenshots)
```

## Documentation

- Full report with objectives, steps, challenges and answers to Q1-Q6: [docs/report.md](docs/report.md)
- Terminal and UI evidence for every task: [docs/evidence.md](docs/evidence.md)
