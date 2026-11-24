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

## Task 4 - Platform objects and Sealed Secrets

```
$ kubectl get app sealed-secrets -n argocd; kubectl get pods -n sealed-secrets
NAME             SYNC STATUS   HEALTH STATUS
sealed-secrets   Synced        Healthy
NAME                                        READY   STATUS    RESTARTS      AGE
sealed-secrets-controller-dddc94564-n6qs4   1/1     Running   1 (28m ago)   42h
```

```
$ ls -l ../dso202-keys/sealing-key.backup.yaml   # backed up BEFORE sealing; contents never recorded
-rw-------@ 1 kanisha13  staff  7095 Nov 23 00:26 ../dso202-keys/sealing-key.backup.yaml
```

```
$ kubectl get sealedsecret,secret -n dso202-dev; kubectl get sealedsecret,secret -n dso202-staging
NAME                                               STATUS   SYNCED   AGE
sealedsecret.bitnami.com/tasktracker-credentials            True     13m

NAME                             TYPE     DATA   AGE
secret/tasktracker-credentials   Opaque   4      13m
NAME                                               STATUS   SYNCED   AGE
sealedsecret.bitnami.com/tasktracker-credentials            True     13m

NAME                             TYPE     DATA   AGE
secret/tasktracker-credentials   Opaque   4      13m
```

```
$ git log --all -p -S"$(grep ^DB_PASSWORD= secrets-plain/dev.env | cut -d= -f2)" --oneline | wc -l   # plaintext dev password in history: 0 lines
       0
```

```
$ git log --all -p -S"$(grep ^DB_PASSWORD= secrets-plain/staging.env | cut -d= -f2)" --oneline | wc -l   # plaintext staging password in history: 0 lines
       0
```

```
$ git status --short --ignored
 M docs/evidence.md
!! .DS_Store
!! docs/.DS_Store
!! secrets-plain/
```

### Q2
Strict scope binds each SealedSecret to one namespace *and* one Secret name. It prevents someone who can read the sealed YAML (the public repo) from re-targeting it: copying the dev SealedSecret into another namespace, or renaming it, makes the controller refuse to decrypt it, so a dev credential cannot be harvested by creating a SealedSecret in a namespace someone else controls. What is lost is flexibility: renaming the Secret or moving it to another namespace means re-sealing it. If the sealing key is lost, every existing SealedSecret becomes permanently undecryptable (only the private key can decrypt). The recovery is to restore the key backup before the controller starts, or, if there is no backup, to let the controller generate a new key, re-seal every secret from the original plaintext, commit, and rotate the underlying credentials.

## Task 5 - Deliver the workloads

```
$ git log --oneline --decorate -4; git ls-remote --tags origin
901b126 (HEAD -> main, tag: v1.0.0, origin/main, origin/HEAD) Task 5: smoke test, fix StatefulSet volumeMode drift
80418b6 Task 4: sealed credentials and Tasks 1-3 evidence
97f9340 first commit
901b126300009d2f2a07648441565a18a2d49f78	refs/tags/v1.0.0
```

```
$ kubectl get applications -n argocd
NAME                  SYNC STATUS   HEALTH STATUS
platform-dev          Synced        Healthy
platform-staging      Synced        Healthy
root                  Synced        Healthy
sealed-secrets        Synced        Healthy
tasktracker-dev       Synced        Healthy
tasktracker-staging   Synced        Healthy
```

```
$ kubectl get pods -n dso202-dev --sort-by=.metadata.creationTimestamp -o custom-columns=NAME:.metadata.name,CREATED:.metadata.creationTimestamp,READY:.status.containerStatuses[0].ready
(eval):1: no matches found: custom-columns=NAME:.metadata.name,CREATED:.metadata.creationTimestamp,READY:.status.containerStatuses[0].ready
```

Smoke-test log (PostSync hook, captured during sync):
```
attempt 1: GET http://tasktracker-dev-backend-svc:8080/api/status
{"status":"ok","db":"connected"}
SMOKE TEST PASSED
```

```
$ argocd app get tasktracker-dev | sed -n 1,16p
Name:               argocd/tasktracker-dev
Project:            dso202
Server:             https://kubernetes.default.svc
Namespace:          dso202-dev
URL:                https://localhost:8080/applications/tasktracker-dev
Source:
- Repo:             https://github.com/Kanishapradhan13/dso202-gitops.git
  Target:           main
  Path:             charts/tasktracker
  Helm Values:      ../../environments/dev/values.yaml
SyncWindow:         Sync Allowed
Sync Policy:        Automated (Prune)
Sync Status:        Synced to main (901b126)
Health Status:      Healthy

GROUP  KIND         NAMESPACE   NAME                          STATUS     HEALTH   HOOK      MESSAGE
```

```
$ argocd app get tasktracker-staging | sed -n 1,16p
Name:               argocd/tasktracker-staging
Project:            dso202
Server:             https://kubernetes.default.svc
Namespace:          dso202-staging
URL:                https://localhost:8080/applications/tasktracker-staging
Source:
- Repo:             https://github.com/Kanishapradhan13/dso202-gitops.git
  Target:           v1.0.0
  Path:             charts/tasktracker
  Helm Values:      ../../environments/staging/values.yaml
SyncWindow:         Sync Allowed
Sync Policy:        Manual
Sync Status:        Synced to v1.0.0 (901b126)
Health Status:      Healthy

GROUP  KIND         NAMESPACE       NAME                              STATUS     HEALTH   HOOK      MESSAGE
```

```
$ argocd app history tasktracker-dev
SOURCE  https://github.com/Kanishapradhan13/dso202-gitops.git
ID      DATE                           REVISION
0       2026-11-24 18:54:44 +0600 +06  main (97f9340)
1       2026-11-24 18:54:59 +0600 +06  main (80418b6)
2       2026-11-24 19:04:14 +0600 +06  main (901b126)
3       2026-11-24 19:04:41 +0600 +06  main (901b126)
```

### Root state before and after the first manual staging sync

Before: root Synced/Healthy at main (901b126); tasktracker-staging OutOfSync/Missing. After: root Synced/Healthy at main (901b126); tasktracker-staging Synced/Healthy. root never changed: it tracks the Application objects in Git, not the workloads those Applications deliver, and a manual staging sync changes only the workloads.

### CRUD cycle (dev http://localhost:30080 stack, staging via port-forward 8081/8082)
```
=== dev CRUD (via http://localhost:30090/api/tasks) ===
CREATE:
{"id":5,"title":"GitOps dev task","description":"created via API","status":"pending","created_at":"2026-11-24T13:05:58.138Z"}
READ:
{"id":5,"title":"GitOps dev task","description":"created via API","status":"pending","created_at":"2026-11-24T13:05:58.138Z"}
UPDATE:
{"id":5,"title":"GitOps task","description":"updated","status":"done","created_at":"2026-11-24T13:05:58.138Z"}
DELETE:
http 204
=== staging CRUD (via http://localhost:8082/api/tasks) ===
CREATE:
{"id":4,"title":"GitOps staging task","description":"created via API","status":"pending","created_at":"2026-11-24T13:05:58.449Z"}
READ:
{"id":4,"title":"GitOps staging task","description":"created via API","status":"pending","created_at":"2026-11-24T13:05:58.449Z"}
UPDATE:
{"id":4,"title":"GitOps task","description":"updated","status":"done","created_at":"2026-11-24T13:05:58.449Z"}
DELETE:
http 204
```

### Q3
`Synced` compares the live objects with what Git renders: do they match? `Healthy` asks whether the live workload is actually working (Pods Ready, Deployments available, Jobs complete). They are independent. In this task: before the Secret was pushed, tasktracker-dev had its manifests applied, but its DB Pod sat in `CreateContainerConfigError` ("secret tasktracker-credentials not found"), so the Application was applied but `Progressing`, never Healthy. The reverse also happened: the StatefulSet reported OutOfSync while Healthy (volumeClaimTemplates defaults), fixed by setting `volumeMode: Filesystem` in the chart. A Synced-but-not-Healthy app is easy to provoke by pushing a bad image tag.

Screenshots: docs/screenshots/task5-dev-tree.png

## Task 6 - Argo CD access control

```
$ argocd account list
NAME      ENABLED  CAPABILITIES
admin     true     login
reviewer  true     login

# reviewer login: argocd login localhost:8080 --username reviewer --name reviewer  -> logged in

# BEFORE enabling logs in Listing 5 (expected yes / no / no):
$ argocd --argocd-context reviewer account can-i get applications dso202/tasktracker-dev
yes
$ argocd --argocd-context reviewer account can-i sync applications dso202/tasktracker-dev
no
$ argocd --argocd-context reviewer account can-i get logs dso202/tasktracker-dev
no

$ argocd --argocd-context reviewer proj get platform
FATAL ... PermissionDenied desc = permission denied: projects, get, platform, sub: reviewer

# After adding "p, role:reviewer, logs, get, dso202/*, allow" and re-running kubectl apply -k bootstrap/argocd --server-side --force-conflicts:
$ argocd --argocd-context reviewer account can-i get applications dso202/tasktracker-dev
yes
$ argocd --argocd-context reviewer account can-i sync applications dso202/tasktracker-dev
no
$ argocd --argocd-context reviewer account can-i get logs dso202/tasktracker-dev
yes

$ argocd account list (admin session restored)
argocd/platform-dev
argocd/platform-staging
argocd/root
argocd/sealed-secrets
argocd/tasktracker-dev
argocd/tasktracker-staging
```

### Q4
Argo CD RBAC (argocd-rbac-cm, `policy.csv`, plus AppProject roles) controls what a user can do *through Argo CD*: view, sync, override, delete applications, read logs, manage projects, repos and clusters. Kubernetes RBAC (Assignment 2: Role/RoleBinding/ClusterRole, in the cluster, here platform/<env>/rbac.yaml) controls what a Kubernetes identity can do against the Kubernetes API (kubectl, ServiceAccounts, Pods). They are separate layers: Argo CD's application controller uses its own ServiceAccount with broad Kubernetes rights, and a human's Argo CD permissions are enforced by the Argo CD API server, not by Kubernetes. If the organisation's IdP were connected through SSO (descriptor 4.4.2), the users would no longer be local accounts (`accounts.reviewer` in argocd-cm); `policy.csv` would map IdP groups instead of local usernames, for example `g, <idp-group-name>, role:reviewer`, with `scopes` set in argocd-rbac-cm so group claims are read. The roles and `p,` rules would stay the same, only the `g,` subject lines change. SSO was not configured here.

Screenshot: docs/screenshots/task6-reviewer-logs.png

## Task 8 - Drift, pruning and guardrails

### Drill 1 - self-heal in dev
```
PREDICTION: dev has selfHeal=true, so Argo CD will revert replicas 3 -> 1 within seconds.

$ kubectl get deploy tasktracker-dev-backend -n dso202-dev
NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
tasktracker-dev-backend   1/1     1            1           24m

$ kubectl scale deploy tasktracker-dev-backend -n dso202-dev --replicas=3
deployment.apps/tasktracker-dev-backend scaled
t+3s: ready=1/3 desired(spec)=3  app=Synced
t+6s: ready=1/3 desired(spec)=3  app=OutOfSync
t+9s: ready=1/1 desired(spec)=1  app=Synced
t+12s: ready=1/1 desired(spec)=1  app=Synced
t+15s: ready=1/1 desired(spec)=1  app=Synced
t+18s: ready=1/1 desired(spec)=1  app=Synced
t+21s: ready=1/1 desired(spec)=1  app=Synced
t+24s: ready=1/1 desired(spec)=1  app=Synced

$ kubectl get deploy,pods -n dso202-dev
NAME                                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/tasktracker-dev-backend    1/1     1            1           24m
deployment.apps/tasktracker-dev-frontend   1/1     1            1           24m

NAME                                            READY   STATUS        RESTARTS   AGE
pod/tasktracker-dev-backend-86496745fb-8xwrr    1/1     Running       0          24m
pod/tasktracker-dev-backend-86496745fb-fsqgt    1/1     Terminating   0          26s
pod/tasktracker-dev-backend-86496745fb-z2v9p    1/1     Terminating   0          26s
pod/tasktracker-dev-db-0                        1/1     Running       0          42h
pod/tasktracker-dev-frontend-69f7c45989-2xjrw   1/1     Running       0          24m
```
Result matched the prediction: the hand edit was reverted by self-heal within about 9 seconds (OutOfSync for roughly one poll).

### Drill 2 - drift in staging (no automated sync)
```
PREDICTION: staging has no automated sync, so replicas stay at 3 and the app turns OutOfSync until a manual sync.

$ kubectl scale deploy tasktracker-staging-backend -n dso202-staging --replicas=3
deployment.apps/tasktracker-staging-backend scaled

$ kubectl get deploy tasktracker-staging-backend -n dso202-staging (after 40 s)
NAME                          READY   UP-TO-DATE   AVAILABLE   AGE
tasktracker-staging-backend   3/3     3            3           13m

$ kubectl get app tasktracker-staging -n argocd
NAME                  SYNC STATUS   HEALTH STATUS
tasktracker-staging   OutOfSync     Healthy

$ argocd app diff tasktracker-staging

===== apps/Deployment dso202-staging/tasktracker-staging-backend ======
112c112
<   replicas: 3
---
>   replicas: 1

$ argocd app sync tasktracker-staging
2026-11-24T19:18:36+06:00   apps  Deployment   dso202-staging  tasktracker-staging-backend       OutOfSync  Healthy              
2026-11-24T19:18:36+06:00   apps  Deployment   dso202-staging  tasktracker-staging-frontend        Synced   Healthy              
2026-11-24T19:18:40+06:00   apps  Deployment  dso202-staging  tasktracker-staging-backend    Synced  Healthy              
2026-11-24T19:18:42+06:00   apps  Deployment   dso202-staging  tasktracker-staging-backend        Synced  Healthy              deployment.apps/tasktracker-staging-backend serverside-applied
2026-11-24T19:18:44+06:00   apps  Deployment  dso202-staging  tasktracker-staging-frontend        Synced  Healthy              deployment.apps/tasktracker-staging-frontend serverside-applied
Phase:              Succeeded
Message:            successfully synced (no more tasks)
apps   Deployment   dso202-staging  tasktracker-staging-backend       Synced     Healthy            deployment.apps/tasktracker-staging-backend serverside-applied
apps   Deployment   dso202-staging  tasktracker-staging-frontend      Synced     Healthy            deployment.apps/tasktracker-staging-frontend serverside-applied

$ kubectl get deploy tasktracker-staging-backend -n dso202-staging && kubectl get app tasktracker-staging -n argocd
NAME                          READY   UP-TO-DATE   AVAILABLE   AGE
tasktracker-staging-backend   1/1     1            1           14m
NAME                  SYNC STATUS   HEALTH STATUS
tasktracker-staging   Synced        Healthy
```
Result matched the prediction: staging kept the drift (3/3, OutOfSync) until a manual sync restored 1 replica. Dev was unaffected.

### Task 6 follow-up - Pods were not visible in the Argo CD tree

While preparing the reviewer screenshot, the Argo CD UI showed no ReplicaSet or Pod nodes (even for admin), so there was nothing to open the LOGS tab on. Cause: the dso202 AppProject's namespaceResourceWhitelist did not list ReplicaSet or Pod, and Argo CD hides kinds the project does not allow. Fix (via Git, commit 60eea2b): added ReplicaSet and Pod to argocd/projects/dso202.yaml with a comment on each. ResourceQuota stays denied, so Task 8 Drill 4 is unaffected.
```
$ argocd app get tasktracker-dev -o tree   # after the fix

KIND/NAME                                          STATUS  HEALTH   MESSAGE
Service/tasktracker-dev-frontend-svc               Synced  Healthy  service/tasktracker-dev-frontend-svc serverside-applied
Deployment/tasktracker-dev-backend                 Synced  Healthy  deployment.apps/tasktracker-dev-backend serverside-applied
└─ReplicaSet/tasktracker-dev-backend-86496745fb            Healthy  
  └─Pod/tasktracker-dev-backend-86496745fb-8xwrr           Healthy  
Deployment/tasktracker-dev-frontend                Synced  Healthy  deployment.apps/tasktracker-dev-frontend serverside-applied
└─ReplicaSet/tasktracker-dev-frontend-69f7c45989           Healthy  
  └─Pod/tasktracker-dev-frontend-69f7c45989-2xjrw          Healthy  
StatefulSet/tasktracker-dev-db                     Synced  Healthy  statefulset rolling update complete 1 pods at revision tasktracker-dev-db-7fb96fc9c5...
└─Pod/tasktracker-dev-db-0                                 Healthy  
ConfigMap/tasktracker-dev-config                   Synced           configmap/tasktracker-dev-config serverside-applied
```
