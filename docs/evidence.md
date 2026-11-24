# Evidence - DSO202 Assignment 4

Command output is copied from the terminal. Screenshots are in docs/screenshots/.

## Task 1 - Repository, chart contract, cluster

```
$ docker --version; kind version; kubectl version --client | head -1; helm version --short; git --version; argocd version --client | head -1; kubeseal --version
Docker version 29.2.0, build 0b9d198
kind v0.32.0 go1.26.3 darwin/arm64
Client Version: v1.34.1
v4.3.0+gbec5b06
git version 2.50.1 (Apple Git-155)
argocd: v3.5.6+c2b1e30
kubeseal version: 0.40.0
```

```
$ helm repo add sealed-secrets https://bitnami.github.io/sealed-secrets; helm repo update; helm search repo sealed-secrets/sealed-secrets --versions | head -5
"sealed-secrets" already exists with the same configuration, skipping
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "podinfo" chart repository
...Successfully got an update from the "sealed-secrets" chart repository
...Successfully got an update from the "argo" chart repository
...Successfully got an update from the "bitnami" chart repository
Update Complete. ⎈Happy Helming!⎈
NAME                         	CHART VERSION	APP VERSION	DESCRIPTION                                  
sealed-secrets/sealed-secrets	2.22.0       	0.41.2     	Helm chart for the sealed-secrets controller.
sealed-secrets/sealed-secrets	2.21.0       	0.41.2     	Helm chart for the sealed-secrets controller.
sealed-secrets/sealed-secrets	2.20.0       	0.40.0     	Helm chart for the sealed-secrets controller.
sealed-secrets/sealed-secrets	2.19.3       	0.39.1     	Helm chart for the sealed-secrets controller.
```

### Chart contract

| ID | Requirement | Where satisfied |
|----|-------------|-----------------|
| C1 | image repo/tag are values | values.yaml `*.image.repository/tag` |
| C2 | per-tier config from values | templates/configmap.yaml |
| C3 | no Secret rendered; `existingSecret: tasktracker-credentials` | values.yaml, envFrom in database/backend |
| C4 | readiness probes (backend GET /api/status) | backend.yaml, database.yaml, frontend.yaml |
| C5 | sync waves db 0, backend 1, frontend 2 | `argocd.argoproj.io/sync-wave` annotations |
| C6 | progressDeadlineSeconds 120 on backend and frontend | backend.yaml, frontend.yaml |
| C7 | requests and limits on every container | values.yaml, smoke-test-job.yaml |
| C8 | no Namespace/ResourceQuota/LimitRange/Role/RoleBinding in chart | platform/<env>/ owns them |
| C9 | Ingress disabled | values.yaml `ingress.enabled: false`, no template |
| C10 | frontend NodePort 30080 dev / 30081 staging | environments/*/values.yaml |
| C11 | helm lint + template succeed for both envs | below |

```
$ helm lint charts/tasktracker -f environments/dev/values.yaml | tail -2

1 chart(s) linted, 0 chart(s) failed
```

```
$ helm template tasktracker-dev charts/tasktracker -f environments/dev/values.yaml -n dso202-dev | grep -E '^kind:|nodePort' | sort | uniq -c
   1       nodePort: 30080
   1       nodePort: 30090
   1 kind: ConfigMap
   2 kind: Deployment
   1 kind: Job
   3 kind: Service
   1 kind: StatefulSet
```

```
$ helm lint charts/tasktracker -f environments/staging/values.yaml | tail -2

1 chart(s) linted, 0 chart(s) failed
```

```
$ helm template tasktracker-staging charts/tasktracker -f environments/staging/values.yaml -n dso202-staging | grep -E '^kind:|nodePort' | sort | uniq -c
   1       nodePort: 30081
   1       nodePort: 30091
   1 kind: ConfigMap
   2 kind: Deployment
   1 kind: Job
   3 kind: Service
   1 kind: StatefulSet
```

```
$ kind get clusters | grep gitops; kubectl get nodes
dso202-gitops
NAME                          STATUS   ROLES           AGE   VERSION
dso202-gitops-control-plane   Ready    control-plane   49m   v1.36.1
```

```
$ docker port dso202-gitops-control-plane
6443/tcp -> 127.0.0.1:62475
30080/tcp -> 0.0.0.0:30080
30090/tcp -> 0.0.0.0:30090
```

## Task 2 - Argo CD install

```
$ kubectl kustomize bootstrap/argocd | grep -c '^kind: Deployment'; kubectl kustomize bootstrap/argocd | grep -c '^kind: StatefulSet'; kubectl kustomize bootstrap/argocd | grep 'image:' | sort -u
6
1
        image: ghcr.io/dexidp/dex:v2.45.1
        image: public.ecr.aws/docker/library/redis:8.2.3-alpine
        image: quay.io/argoproj/argocd:v3.5.6
```

```
$ kubectl get pods -n argocd
NAME                                                READY   STATUS    RESTARTS   AGE
argocd-application-controller-0                     1/1     Running   0          48m
argocd-applicationset-controller-58bb5c7479-qv2l5   1/1     Running   0          48m
argocd-dex-server-dd6b85d9c-gh8jw                   1/1     Running   0          48m
argocd-notifications-controller-6b85c65458-tqn6x    1/1     Running   0          48m
argocd-redis-869b85489d-jdqbt                       1/1     Running   0          48m
argocd-repo-server-5bf66565cd-p7hvw                 1/1     Running   0          48m
argocd-server-7474bb8f76-w9d9t                      1/1     Running   0          48m
```

```
$ kubectl get crd | grep argoproj
applications.argoproj.io      2026-11-22T17:56:04Z
applicationsets.argoproj.io   2026-11-22T17:56:05Z
appprojects.argoproj.io       2026-11-22T17:56:05Z
```

```
$ kubectl get cm argocd-cm -n argocd -o jsonpath='{.data.timeout\.reconciliation}{"
"}{.data.accounts\.reviewer}{"
"}'
60s
login
```

```
$ argocd version | head -3
argocd: v3.5.6+c2b1e30
  BuildDate: 2026-10-20T19:01:52Z
  GitCommit: c2b1e3017e2cec86b122172e861dcd026453ae44
```

Screenshot: docs/screenshots/task2-argocd-ui.png (Argo CD v3.5.6 after sign-in).

## Task 3 - AppProjects and root Application

```
$ kubectl get appproject,application -n argocd
NAME                              AGE
appproject.argoproj.io/default    45m
appproject.argoproj.io/dso202     18m
appproject.argoproj.io/platform   19m

NAME                                          SYNC STATUS   HEALTH STATUS
application.argoproj.io/platform-dev          Synced        Healthy
application.argoproj.io/platform-staging      Synced        Healthy
application.argoproj.io/root                  Synced        Healthy
application.argoproj.io/sealed-secrets        Synced        Healthy
application.argoproj.io/tasktracker-dev       OutOfSync     Progressing
application.argoproj.io/tasktracker-staging   Unknown       Healthy
```

```
$ argocd app get root | head -26
Name:               argocd/root
Project:            platform
Server:             https://kubernetes.default.svc
Namespace:          argocd
URL:                https://localhost:8080/applications/root
Source:
- Repo:             https://github.com/Kanishapradhan13/dso202-gitops.git
  Target:           main
  Path:             argocd
SyncWindow:         Sync Allowed
Sync Policy:        Automated (Prune)
Sync Status:        Synced to main (97f9340)
Health Status:      Healthy

GROUP        KIND         NAMESPACE  NAME                 STATUS  HEALTH  HOOK  MESSAGE
argoproj.io  AppProject   argocd     dso202               Synced                appproject.argoproj.io/dso202 serverside-applied
argoproj.io  Application  argocd     sealed-secrets       Synced                application.argoproj.io/sealed-secrets serverside-applied
argoproj.io  Application  argocd     platform-staging     Synced                application.argoproj.io/platform-staging serverside-applied
argoproj.io  Application  argocd     platform-dev         Synced                application.argoproj.io/platform-dev serverside-applied
argoproj.io  Application  argocd     tasktracker-dev      Synced                application.argoproj.io/tasktracker-dev serverside-applied
argoproj.io  Application  argocd     tasktracker-staging  Synced                application.argoproj.io/tasktracker-staging serverside-applied
```

```
$ argocd proj get dso202
Name:                        dso202
Description:                 Task Tracker workloads
Destinations:                https://kubernetes.default.svc,dso202-dev
                             https://kubernetes.default.svc,dso202-staging
Repositories:                https://github.com/Kanishapradhan13/dso202-gitops.git
Source Namespaces:           <none>
Scoped Repositories:         <none>
Allowed Cluster Resources:   <none>
Scoped Clusters:             <none>
Denied Namespaced Resources: <none>
Signature keys:              <none>
Orphaned Resources:          disabled
```

Screenshot: docs/screenshots/task3-root-tree.png
