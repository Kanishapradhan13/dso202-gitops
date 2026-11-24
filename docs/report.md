# DSO202 Assignment 4 - GitOps delivery of the Task Tracker with Argo CD

Repository: https://github.com/Kanishapradhan13/dso202-gitops (public). Cluster: kind `dso202-gitops`.
Screenshots are in `docs/screenshots/`; the same screenshots are indexed per task in [evidence.md](evidence.md).

## 1. Objectives

1. Deliver the Assignment 1-3 Task Tracker to Kubernetes **only through Git**, with Argo CD pulling and reconciling (the four OpenGitOps principles: declarative, versioned, pulled automatically, continuously reconciled).
2. Install Argo CD v3.5.6 declaratively and bootstrap the cluster with an app-of-apps root Application.
3. Separate trust: a `platform` project for platform components, and a least-privilege `dso202` project for workloads.
4. Keep credentials out of Git with Sealed Secrets, and protect the sealing key.
5. Run two environments from one chart: dev follows `main` (automated, self-heal, prune), staging follows a release tag (manual).
6. Add access control (a read-only `reviewer` account), and prove drift handling, pruning and project guardrails with drills.
7. Prove the system can be rebuilt from Git plus the sealing key.

## 2. Environment

| Item | Value |
|------|-------|
| Argo CD / argocd CLI | v3.5.6 |
| Sealed Secrets | chart 2.20.0, controller 0.40.0, kubeseal v0.40.0 |
| kind / node | kind v0.32.0, kindest/node v1.36.1, one node |
| Images | sarojsanyasi/dso202-frontend, -backend, -db, tag 1.0 |
| Repo layout | cluster/, bootstrap/, argocd/, platform/, charts/, environments/, docs/ |

## 3. Steps

### Task 1 - Repository, chart contract, cluster
Created the repository with `.gitignore` as the first commit, then reshaped the Assignment 3 Helm chart into `charts/tasktracker` to meet the contract: image repository/tag from values, config from values, no Secret rendered (an `existingSecret` is referenced), readiness probes (backend `GET /api/status`), sync waves db 0 / backend 1 / frontend 2, `progressDeadlineSeconds: 120`, requests and limits on every container, no Namespace/Quota/LimitRange/Role/RoleBinding in the chart, Ingress disabled, frontend NodePort 30080 (dev) and 30081 (staging). Deleted the old `dso202` cluster and created `dso202-gitops` with host ports 30080 and 30090 mapped.

![tools](screenshots/t1-1-tool-check.png)
![lint and template](screenshots/t1-2-lint-template.png)
![cluster](screenshots/t1-3-cluster.png)

### Task 2 - Install Argo CD
Wrote a kustomization pinned to the Argo CD v3.5.6 install manifest plus two patches (`argocd-cm`: 60 s polling, a `reviewer` account, annotation resource tracking; `argocd-rbac-cm`). Rendered it (6 Deployments, 1 StatefulSet, images from ghcr.io, public.ecr.aws and quay.io only), applied with `--server-side --force-conflicts`, and confirmed 7 Pods and 3 CRDs.

![render](screenshots/t2-1-render.png)
![pods and CRDs](screenshots/t2-2-pods-crds.png)
![Argo CD UI](screenshots/task2-argocd-ui.png)

### Task 3 - AppProjects and the root Application
Created the `platform` AppProject (the only one allowed to target `argocd`) and the root Application by hand, once. The root Application delivers `argocd/`: the least-privilege `dso202` project (no cluster-scoped kinds; only the kinds the chart renders) and five Applications in sync-wave order (project -3, sealed-secrets -2, platform-dev/-staging -1, tasktracker-dev/-staging 0).

![apps and projects](screenshots/t3-1-apps-projects.png)
![dso202 project](screenshots/t3-2-project-whitelist.png)
![root tree](screenshots/task3-root-tree.png)
![children expanded](screenshots/task3-root-tree1.png)

### Task 4 - Platform and Sealed Secrets
Delivered the Sealed Secrets controller through Git (chart 2.20.0). Backed up the sealing key to `../dso202-keys/` (mode 600, outside the repo) before sealing anything. Generated different random credentials for dev and staging in the gitignored `secrets-plain/`, sealed them with strict scope (namespace + name) into `platform/<env>/tasktracker-credentials-sealed.yaml`, and delivered per-environment namespace, quota, limits and RBAC from `platform/`. A search of the full Git history for each plaintext password finds nothing.

![sealed secrets](screenshots/t4-1-sealed-secrets.png)
![history search](screenshots/t4-2-history-clean.png)

### Task 5 - Deliver the workloads
Added a PostSync smoke-test Job to the chart, tagged `v1.0.0`, and added `tasktracker-dev` (main, automated) and `tasktracker-staging` (tag `v1.0.0`, no automated block). Pods came up in wave order (db, backend, frontend); the smoke test passed on the first attempt. Staging was synced manually. A create/read/update/delete cycle worked in both environments. `root` did not change across the first staging sync because it tracks the Application objects, not the workloads they deliver.

![apps and pods](screenshots/t5-1-apps-pods.png)
![smoke test](screenshots/t5-2-smoke-test.png)
![app get dev](screenshots/t5-3-app-get-dev.png)
![app get staging](screenshots/t5-4-app-get-staging.png)
![CRUD](screenshots/t5-5-crud.png)
![dev tree](screenshots/task5-dev-tree.png)
![dev app](screenshots/task5-dev-app.png)

### Task 6 - Argo CD access control
Set a password for the local `reviewer` account and tested `can-i` before and after enabling the `logs` permission: get applications yes, sync no, logs no, then logs yes after adding `p, role:reviewer, logs, get, dso202/*, allow` to the RBAC patch and re-applying the bootstrap. The `platform` project is denied to the reviewer.

![reviewer permissions](screenshots/t6-1-reviewer.png)
![reviewer logs](screenshots/task6-reviewer-logs.png)

### Task 7 - Release and recovery (partial)
The tutor-issued `1.1` images for the frontend and backend were not published (Docker Hub shows only `1.0` on all three repositories), so the release (Part A) and faulty-backend recovery (Part B) could not be performed, and tags `v1.1.0` and `v1.2.0` do not exist. What could be shown without them: `argocd app rollback` is refused while auto-sync is enabled, and the revert workflow is demonstrated by the Drill 4 revert commit in Task 8.

![rollback refused](screenshots/t7-1-rollback-refused.png)

### Task 8 - Drift, pruning and guardrails
Each drill has a prediction, an action, an observation and a restore.

- **Drill 1 (dev, self-heal):** predicted the manual scale to 3 would be reverted. It was, within about nine seconds.
- **Drill 2 (staging, no automated sync):** predicted the drift would persist. Replicas stayed at 3 and the app went OutOfSync; `argocd app diff` showed `replicas: 3` against `1`, and a manual sync restored it.
- **Drill 3 (pruning):** a throwaway ConfigMap was added to Git and appeared; its removal from Git pruned it.
- **Drill 4 (guardrail):** a ResourceQuota added to the chart was refused: `resource :ResourceQuota is not permitted in project dso202`. Dev stayed Healthy but OutOfSync, staging was unaffected, and `git revert` restored Synced.

![drill 1](screenshots/t8-1-drill1-selfheal.png)
![drill 2](screenshots/t8-2-drill2-staging.png)
![drill 3](screenshots/t8-3-drill3-prune.png)
![drill 4](screenshots/t8-4-drill4-guardrail.png)

### Task 9 - Rebuild from Git
Backed up the sealing key again and recorded the commit (`609c6e457366c96b6a98938c6ed4a475e603f212`, equal to `origin/main`). Deleted and recreated the cluster, created the `sealed-secrets` namespace and restored the key **before** the controller existed, installed Argo CD, applied the root app, and watched the Applications arrive in wave order. Re-logged in with the new admin password, synced staging manually, verified both environments (the database was re-seeded; a task was added in each), and backed the key up again. The SealedSecrets decrypted with the restored key (the controller log says it registered the existing private key).

![backup, delete, create](screenshots/t9-1-backup-delete-create.png)
![restore attempt](screenshots/t9-2-restore-key-install-argocd.png)
![key restored, Argo CD ready](screenshots/t9-3-key-restored-argocd-ready.png)
![root and waves](screenshots/t9-4-root-waves.png)
![login and staging sync](screenshots/t9-5-login-sync-staging.png)
![verify and re-backup](screenshots/t9-6-verify-tasks-rebackup.png)

## 4. Challenges and how they were solved

| Challenge | Cause | Resolution |
|-----------|-------|------------|
| Argo CD kustomize patch failed: "no resource matches strategic merge patch" | The upstream ConfigMaps have no namespace when patches are matched, so a patch naming `argocd` found no target | Removed `namespace:` from the two patch files |
| `tasktracker-dev` started before its credentials existed | The first commit already contained the workload Applications | It sat in `CreateContainerConfigError` until the SealedSecret was pushed; expected and documented |
| Dev Healthy but permanently OutOfSync | The database StatefulSet's `volumeClaimTemplates` is defaulted by the API server | Set `apiVersion`, `kind` and `volumeMode: Filesystem` in the chart |
| Smoke-test Job never seen | The first sync stalled on the missing Secret; and a succeeded hook is deleted | Re-synced after the fix and followed the Job log live while it ran |
| No Pods or ReplicaSets in the Argo CD tree, so the reviewer could not open logs | The `dso202` project whitelist did not list `ReplicaSet` or `Pod`, and Argo CD hides kinds the project does not allow | Added both kinds (with comments) to the whitelist in Git; ResourceQuota stays denied |
| Argo CD and kubeseal downloads very slow, one cut off at 178 MB | Slow network | Resumed the download with `curl -C -` |
| Argo CD UI unreachable after a while | Docker Desktop had been paused, freezing the cluster | Resumed Docker, waited for the node to become Ready, restarted the port-forward |
| Sealing-key restore failed on the first attempt (Task 9) | `kubectl` flattens a one-item List into a single Secret, so my `jq` list filter found nothing | Applied `jq` to the object itself; no controller existed yet, so nothing was lost |
| Argo CD Pods stuck in `CreateContainerConfigError` after the rebuild | The `argocd-redis` secret is created by the redis init container, which was still pulling its image | Waited; the Pods retried and became Ready |
| Task 7 could not be done | Tutor-issued `1.1` images do not exist on Docker Hub | Documented; shown only what does not depend on `1.1` |
| Browser helper could not find the backend Pod | See the whitelist item above | Fixed in Git, then re-tested |

## 5. Answers to the questions

**Q1 - Why is `platform` applied by hand while `dso202` is created by the root app, and what is the risk if `dso202` could deploy into `argocd`?**
The root Application must belong to a project that already exists, so `platform` (the only project allowed to target the `argocd` namespace) has to be created before Argo CD can deliver anything from Git; every later project is an ordinary object delivered by root. If `dso202` could deploy into `argocd`, anyone able to merge a workload change could ship an Application, AppProject or RBAC ConfigMap into Argo CD's own namespace and grant themselves any project, destination or cluster-wide right: a privilege escalation from "can edit a values file" to "controls the cluster". Whitelist additions made in Task 6 (`ReplicaSet`, `Pod`) are runtime children of Deployments and StatefulSets, each carries a comment, and `ResourceQuota` and other cluster objects remain denied.

**Q2 - What does strict scope prevent, what is lost, and what if the sealing key is lost?**
Strict scope ties a SealedSecret to one namespace and one Secret name, so copying the sealed YAML from the public repo into another namespace or renaming it makes decryption fail; a dev credential cannot be harvested elsewhere. What is lost is flexibility: renaming or moving a Secret means re-sealing it. If the sealing key is lost, every existing SealedSecret is permanently undecryptable. Recovery: restore the backed-up key before the controller starts (done in Task 9); with no backup, let the controller generate a new key, re-seal every secret from its plaintext, commit, and rotate the underlying credentials.

**Q3 - What is the difference between Synced and Healthy?**
Synced says the live objects match what Git renders. Healthy says the live workload is actually working (Pods Ready, Jobs complete). They are independent. In this task, before the SealedSecret was pushed, `tasktracker-dev` had its manifests applied but its database Pod was in `CreateContainerConfigError`, so it was not Healthy. The reverse also happened: the StatefulSet was Healthy but OutOfSync because of `volumeClaimTemplates` defaults. A bad image tag in Git would give Synced but Degraded.

**Q4 - Argo CD RBAC vs Kubernetes RBAC, and what changes with SSO?**
Argo CD RBAC (`argocd-rbac-cm` `policy.csv`, plus AppProject roles) decides what a user may do through Argo CD: view, sync or delete apps, read logs, manage projects. Kubernetes RBAC (Assignment 2, `platform/<env>/rbac.yaml`) decides what a Kubernetes identity may do against the Kubernetes API (kubectl, ServiceAccounts, Pods). They are separate layers; Argo CD's controller acts through its own ServiceAccount. With SSO through the organisation's IdP, the local `accounts.reviewer` would go away and `policy.csv` would map IdP groups instead of usernames (`g, <idp-group>, role:reviewer`, with `scopes` configured); the `p,` rules stay the same. SSO was not configured here.

**Q5 - Why is `argocd app rollback` refused, what is the GitOps equivalent, and why `git revert` rather than deleting history?**
Rollback is refused because the app has automated sync: the screenshot shows `rollback cannot be initiated when auto-sync is enabled`. A rollback would push the cluster to an old revision, and the auto-sync would immediately move it back to what Git says, so the two would fight. The GitOps equivalent is to change Git: `git revert` the bad commit and let Argo CD sync the revert. `git revert` is preferred to deleting the commit because it keeps an auditable, linear history that others have already pulled; rewriting history would need a force-push, would break everyone's clones, and would erase the record of what went wrong. (The revert workflow was exercised in Task 8, Drill 4. The faulty-backend scenario itself was not run because the `1.1` images were not available.)

**Q6 - (a) one repository for chart and environment config; (b) what is outside GitOps control?**
(a) Advantages: one pull request changes chart and values together and is reviewed once; one clone, one history, one place to look. Disadvantages: every environment change is a commit to the same repository as the chart, so app-release churn and config churn mix and the polling/diff cost grows; and access control is coarse, because anyone who can write the chart can also edit production values. Argo CD's best-practice guidance separates configuration from source code for these reasons.
(b) Outside GitOps control: the **bootstrap layer** (Argo CD itself and the first `kubectl apply -k`), usually handled by a one-off pipeline or Terraform that installs Argo CD and then lets it manage itself; the **root Application and `platform` project**, applied once by the bootstrap and then guarded by RBAC and branch protection; the **sealing key**, backed up to an offline secret manager or vault with restricted access and rotated on a schedule; and **database contents**, protected with volume snapshots, backups and tested restores, because Git holds configuration, not data.

## 6. Results and known gaps

| Task | Status |
|------|--------|
| 1 Repo, chart contract, cluster | Done |
| 2 Install Argo CD | Done |
| 3 Projects and root | Done |
| 4 Platform and Sealed Secrets | Done |
| 5 Deliver workloads | Done |
| 6 Access control | Done |
| 7 Release and recovery | **Partial**: rollback refusal shown; Part A, Part B and tags `v1.1.0`/`v1.2.0` not possible without the tutor's `1.1` images |
| 8 Drift, pruning, guardrails | Done (four drills) |
| 9 Rebuild from Git | Done (without the 1.1 images) |
| 10 Bonus (multi-source) | Not attempted |

