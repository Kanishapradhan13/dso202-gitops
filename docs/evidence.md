# Evidence - DSO202 Assignment 4

Every item below is a screenshot of a command run in the terminal (or the Argo CD / app UI where noted). Images are in `docs/screenshots/`.

## Task 1 - Repository, chart contract and cluster

**Tool versions and the pinned Sealed Secrets chart 2.20.0 (app 0.40.0)**

![Tool versions and the pinned Sealed Secrets chart 2.20.0 (app 0.40.0)](screenshots/t1-1-tool-check.png)

**helm lint and helm template for dev and staging: kinds, NodePorts, sync waves, progressDeadlineSeconds**

![helm lint and helm template for dev and staging: kinds, NodePorts, sync waves, progressDeadlineSeconds](screenshots/t1-2-lint-template.png)

**kind cluster dso202-gitops, node Ready, host port mappings, Git history**

![kind cluster dso202-gitops, node Ready, host port mappings, Git history](screenshots/t1-3-cluster.png)

## Task 2 - Install Argo CD

**Rendered manifests: 6 Deployments, 1 StatefulSet, no Docker Hub images, argocd-cm patch**

![Rendered manifests: 6 Deployments, 1 StatefulSet, no Docker Hub images, argocd-cm patch](screenshots/t2-1-render.png)

**7 Argo CD Pods Running and the 3 CRDs**

![7 Argo CD Pods Running and the 3 CRDs](screenshots/t2-2-pods-crds.png)

**Argo CD UI after sign-in (browser)**

![Argo CD UI after sign-in (browser)](screenshots/task2-argocd-ui.png)

## Task 3 - AppProjects and the root Application

**Projects and Applications; argocd app get root**

![Projects and Applications; argocd app get root](screenshots/t3-1-apps-projects.png)

**argocd proj get dso202 (no cluster-scoped kinds) and the namespaced whitelist**

![argocd proj get dso202 (no cluster-scoped kinds) and the namespaced whitelist](screenshots/t3-2-project-whitelist.png)

**root Application resource tree (browser)**

![root Application resource tree (browser)](screenshots/task3-root-tree.png)

**The five child Applications, expanded (browser)**

![The five child Applications, expanded (browser)](screenshots/task3-root-tree1.png)

## Task 4 - Platform and Sealed Secrets

**Controller, sealing-key backup outside the repo, SealedSecrets decrypted into Secrets**

![Controller, sealing-key backup outside the repo, SealedSecrets decrypted into Secrets](screenshots/t4-1-sealed-secrets.png)

**Search of the full Git history for each plaintext password: nothing found; git status --ignored**

![Search of the full Git history for each plaintext password: nothing found; git status --ignored](screenshots/t4-2-history-clean.png)

## Task 5 - Deliver the workloads

**Applications, Pod creation order, release tag**

![Applications, Pod creation order, release tag](screenshots/t5-1-apps-pods.png)

**PostSync smoke-test Job log: SMOKE TEST PASSED**

![PostSync smoke-test Job log: SMOKE TEST PASSED](screenshots/t5-2-smoke-test.png)

**argocd app get tasktracker-dev (resource tree with Pods)**

![argocd app get tasktracker-dev (resource tree with Pods)](screenshots/t5-3-app-get-dev.png)

**argocd app get tasktracker-staging (pinned to v1.0.0, manual sync)**

![argocd app get tasktracker-staging (pinned to v1.0.0, manual sync)](screenshots/t5-4-app-get-staging.png)

**Create, read, update, delete cycle in dev and in staging**

![Create, read, update, delete cycle in dev and in staging](screenshots/t5-5-crud.png)

**tasktracker-dev resource tree (browser)**

![tasktracker-dev resource tree (browser)](screenshots/task5-dev-tree.png)

**Task Tracker UI on http://localhost:30080 (browser)**

![Task Tracker UI on http://localhost:30080 (browser)](screenshots/task5-dev-app.png)

## Task 6 - Argo CD access control

**Accounts; reviewer can-i: get applications yes, sync no, get logs yes; platform project denied**

![Accounts; reviewer can-i: get applications yes, sync no, get logs yes; platform project denied](screenshots/t6-1-reviewer.png)

**Reviewer viewing Pod logs in the UI (browser)**

![Reviewer viewing Pod logs in the UI (browser)](screenshots/task6-reviewer-logs.png)

## Task 7 - Release and recovery (partial: tutor images 1.1 not available)

**argocd app rollback refused while auto-sync is enabled; application history; Git graph**

![argocd app rollback refused while auto-sync is enabled; application history; Git graph](screenshots/t7-1-rollback-refused.png)

## Task 8 - Drift, pruning and guardrails

**Drill 1: dev self-heal reverts a manual scale to 3**

![Drill 1: dev self-heal reverts a manual scale to 3](screenshots/t8-1-drill1-selfheal.png)

**Drill 2: staging keeps the drift until argocd app sync**

![Drill 2: staging keeps the drift until argocd app sync](screenshots/t8-2-drill2-staging.png)

**Drill 3: ConfigMap added then removed in Git, and pruned**

![Drill 3: ConfigMap added then removed in Git, and pruned](screenshots/t8-3-drill3-prune.png)

**Drill 4: project refuses ResourceQuota; commit reverted**

![Drill 4: project refuses ResourceQuota; commit reverted](screenshots/t8-4-drill4-guardrail.png)

## Task 9 - Rebuild from Git

**Fresh key backup, commit recorded, cluster deleted and recreated**

![Fresh key backup, commit recorded, cluster deleted and recreated](screenshots/t9-1-backup-delete-create.png)

**Namespace created, Argo CD installed (first attempt at the key restore failed on my jq filter)**

![Namespace created, Argo CD installed (first attempt at the key restore failed on my jq filter)](screenshots/t9-2-restore-key-install-argocd.png)

**Sealing key restored before the controller exists; Argo CD Ready**

![Sealing key restored before the controller exists; Argo CD Ready](screenshots/t9-3-key-restored-argocd-ready.png)

**Root applied; Applications arriving in wave order**

![Root applied; Applications arriving in wave order](screenshots/t9-4-root-waves.png)

**New admin password, manual staging sync, both environments Healthy, secrets decrypted**

![New admin password, manual staging sync, both environments Healthy, secrets decrypted](screenshots/t9-5-login-sync-staging.png)

**Database re-seeded, a task added in each environment, key backed up again**

![Database re-seeded, a task added in each environment, key backed up again](screenshots/t9-6-verify-tasks-rebackup.png)
