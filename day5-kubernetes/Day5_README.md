# Day 5 - Kubernetes Fundamentals (kind cluster)

## Environment Setup
- Docker Desktop running
- kind v0.23.0 (Kubernetes IN Docker - real K8s, runs locally for free)
- kubectl v1.32.2 (client) talking to cluster v1.30.0
- Cluster name: dd-stg
- ingress-nginx controller installed manually (not built into kind)

## Start Environment Every Day
    docker info                          confirm Docker is running
    kubectl cluster-info --context kind-dd-stg
    kubectl get nodes                    confirm cluster is alive

If cluster was deleted and needs recreating:
    kind create cluster --name dd-stg

---

## What Was Built

Simulated FirstNational Bank microservices platform on a single-node
local Kubernetes cluster. Four namespaces representing four bank teams,
with a fully working accounts-service deployment, RBAC, ConfigMap/Secret
injection, Ingress routing, and a NetworkPolicy (with an important
enforcement gap discovered and documented below).

### Namespaces Created
    accounts        - account balance team
    payments        - payment processing team
    fraud           - fraud detection team
    notifications   - alerting team

### accounts-service - Full Stack Built
    Deployment   - 3 replicas, hashicorp/http-echo test image
    Service      - ClusterIP, stable internal DNS name
    ConfigMap    - DATABASE_HOST, LOG_LEVEL
    Secret       - DATABASE_PASSWORD (base64, not encrypted)
    RBAC         - ServiceAccount + Role + RoleBinding (read-only on pods)
    Ingress      - path-based routing /accounts -> accounts-service

### fraud namespace
    fraud-test pod + Service - used to test NetworkPolicy enforcement
    NetworkPolicy            - intended to allow only "payments" namespace
                               traffic in (enforcement gap found - see below)

---

## Core Concepts Learned

### 1. What Kubernetes Actually Is
    You declare DESIRED state in YAML (e.g. "3 replicas always running")
    Kubernetes continuously reconciles ACTUAL state to match desired state
    If a pod dies, the ReplicaSet controller notices the gap and creates
    a replacement automatically - this is "self-healing" and was proven
    hands-on by manually deleting a pod and watching a new one appear
    within seconds.

### 2. Control Plane Components (confirmed via kind output)
    API Server         - front door, every kubectl command goes through here
    etcd                - persistent key-value store, the cluster's memory
    Scheduler           - decides which node runs which pod
    Controller Manager  - watches desired vs actual state, takes corrective action
    Kubelet             - per-node agent that actually starts/stops containers
    CNI plugin          - assigns pod IPs, handles pod networking
                          (kind installs kindnet by default)

### 3. Pod CIDR vs Service CIDR - Two Separate IP Ranges
    Confirmed via: kubectl cluster-info dump | Select-String "cidr|service-cluster"

    --cluster-cidr=10.244.0.0/16              real pod IPs (ephemeral)
    --service-cluster-ip-range=10.96.0.0/16   virtual service IPs (permanent)

    Pod IPs change every time a pod is recreated.
    Service IPs never change - kube-proxy maintains iptables/IPVS rules
    mapping the virtual Service IP to whichever real pod IPs are currently
    healthy behind it. This is why services are addressed by NAME, never
    by pod IP, in any real application code.

    These two ranges must never overlap with your VPC/VNet CIDR from
    Day 2 in a real cloud cluster (EKS/AKS), or routing breaks.

### 4. Deployment -> ReplicaSet -> Pod Chain
    You never create Pods directly in real work.
    Deployment creates and owns a ReplicaSet.
    ReplicaSet creates and owns the actual Pods.
    Confirmed via "Controlled By: ReplicaSet/accounts-service-577dd54cdc"
    in kubectl describe pod output.

    Proved self-healing:
      kubectl delete pod <name>
      -> pod count dropped from 3 to 2 instantly
      -> new pod appeared within seconds, different name, same labels

### 5. Services - Stable Discovery Layer
    selector: app: accounts-service   finds pods by label, not by name
    type: ClusterIP                   internal-only virtual IP
    DNS name: <service>.<namespace>.svc.cluster.local

    Proved with a throwaway test pod:
      kubectl run test-curl --image=curlimages/curl --rm -it --restart=Never
        -- curl accounts-service
      -> "Hello from accounts-service" returned successfully
      -> proves DNS-based service discovery works without ever
         knowing a pod IP

### 6. RBAC - Verified, Not Assumed
    ServiceAccount  = identity for an application/robot (not a human)
    Role            = permission list scoped to ONE namespace
    RoleBinding     = connects identity to permissions

    Created accounts-readonly ServiceAccount with get/list/watch on pods
    only (no delete). Verified with kubectl auth can-i, not just by
    reading the YAML:

      kubectl auth can-i delete pods --as=system:serviceaccount:accounts:accounts-readonly -n accounts
      -> no

      kubectl auth can-i get pods --as=system:serviceaccount:accounts:accounts-readonly -n accounts
      -> yes

    Important gap noticed: the accounts-service Deployment pods were
    running under the "default" ServiceAccount, not accounts-readonly,
    because serviceAccountName was never set on the pod spec. This is a
    common real-world oversight - creating an RBAC identity does not
    automatically attach it to a workload.

### 7. ConfigMap vs Secret - And the Base64 Truth
    ConfigMap = plain text, non-sensitive config (DATABASE_HOST, LOG_LEVEL)
    Secret    = same mechanism, but values are base64-ENCODED, not encrypted

    Proved this directly:
      kubectl get secret accounts-db-secret -n accounts -o yaml
      -> data.DATABASE_PASSWORD: U3VwZXJTZWNyZXRCYW5rUGFzc3dvcmQxMjM=

      Decoded with zero special tools:
      [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("..."))
      -> SuperSecretBankPassword123

      Also proved the encode direction independently using the same
      .NET Convert class - confirming this is universal Base64, nothing
      Kubernetes-specific. The "stringData" field in the YAML is purely
      a write-time convenience - the API server encodes it automatically
      and stores the result under "data" instead.

    Additional finding: kubectl apply stores the original plain-text
    YAML in the "kubectl.kubernetes.io/last-applied-configuration"
    annotation - meaning the secret value was present in etcd TWICE,
    once base64-encoded and once in plain text in the annotation. This
    is why enterprises avoid plain kubectl apply for real secrets and
    use sealed-secrets, External Secrets Operator, or Vault injection
    instead, with real encryption-at-rest enabled on etcd.

### 8. Environment Variable Injection from ConfigMap/Secret
    env:
      - name: DATABASE_HOST
        valueFrom:
          configMapKeyRef: {name: accounts-config, key: DATABASE_HOST}
      - name: DATABASE_PASSWORD
        valueFrom:
          secretKeyRef: {name: accounts-db-secret, key: DATABASE_PASSWORD}

    Verified via kubectl describe pod - the Environment section showed
    correct references resolved to the right ConfigMap/Secret keys.

    Debugging note: the http-echo test image has no shell and no env
    binary (minimal/distroless-style image), so kubectl exec -- env
    failed with "executable file not found in $PATH". Had to use
    kubectl describe pod instead, which reads resolved values straight
    from the Kubernetes API without needing anything inside the
    container itself. This is the correct first command for debugging
    any pod regardless of what's installed inside it.

### 9. Ingress - Path-Based Routing (mirrors Day 2's ALB exactly)
    Ingress resource  = the routing RULES you write (YAML only, does nothing alone)
    Ingress Controller = the actual pod that reads those rules and
                         performs real traffic forwarding (nginx, traefik, etc)

    kind does not ship an Ingress Controller by default - had to install
    ingress-nginx manually. Confirmed it is a completely normal pod:
      kubectl get pods -n ingress-nginx
      -> ingress-nginx-controller-6c6fdf7d88-8zd5s   Running

    Ingress always routes to a SERVICE, never directly to a Deployment
    or Pod.

    Mapping to Day 2 concepts:
      Internet Gateway     -> Ingress Controller (entry point)
      ALB path routing     -> Ingress rules (path-based routing)
      Target Group         -> Service (load balances across pods)
      EC2 instances        -> Pods

    Proved end-to-end with a port-forward tunnel (kind has no real cloud
    LoadBalancer, so ADDRESS field stays empty unlike EKS/AKS):
      kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
      curl http://localhost:8080/accounts
      -> StatusCode 200, "Hello from accounts-service"

    Full proven path: curl -> port-forward tunnel -> ingress-nginx pod
      -> matched "/accounts" rule -> accounts-service -> one of 3 pods
      -> response traveled back

### 10. NetworkPolicy - Written Correctly, Enforcement Gap Found
    Default Kubernetes behavior: ALL pods can reach ALL other pods,
    across ALL namespaces, with zero restriction. NetworkPolicy is
    entirely opt-in.

    Wrote a policy intended to restrict the fraud namespace to only
    accept traffic from the payments namespace:
      podSelector: {}              applies to all pods in fraud namespace
      policyTypes: [Ingress]       only restricts incoming traffic
      from.namespaceSelector       only allow from namespace labeled "payments"

    Tested by creating fraud-test pod/service, then attempting to reach
    it from the accounts namespace (which should have been blocked):
      kubectl run test-from-accounts --image=curlimages/curl -n accounts
        --rm -it --restart=Never -- curl --max-time 5
        fraud-test.fraud.svc.cluster.local
      -> "fraud-service-response" returned successfully

    FINDING: the request succeeded even though it should have been
    blocked. This is because kindnet (kind's default CNI) does NOT
    enforce NetworkPolicy at all - the policy object exists correctly
    in etcd, but nothing reads and acts on it.

    This is a critical, real interview-relevant fact:
      CNIs that DO enforce NetworkPolicy: Calico, Cilium, Azure CNI (AKS),
        AWS VPC CNI with Calico add-on (EKS)
      CNIs that do NOT enforce NetworkPolicy: kindnet, plain Flannel

    Wrong interview answer: "Kubernetes enforces NetworkPolicy by default"
    Correct interview answer: "NetworkPolicy is an API object - whether
      it's actually enforced depends entirely on which CNI plugin the
      cluster uses. You must verify enforcement, not assume it, before
      relying on NetworkPolicy as a real security boundary."

---

## CLI Commands Used
    # Cluster
    kind create cluster --name dd-stg
    kubectl cluster-info --context kind-dd-stg
    kubectl get nodes

    # Namespaces
    kubectl create namespace <name>
    kubectl get namespaces

    # Deployments / Pods
    kubectl apply -f deployment.yaml
    kubectl get pods -n <namespace>
    kubectl delete pod <name> -n <namespace>       (proves self-healing)
    kubectl describe pod <name> -n <namespace>      (debug without shell access)

    # Services
    kubectl apply -f service.yaml
    kubectl get svc -n <namespace>
    kubectl run test-curl --image=curlimages/curl --rm -it --restart=Never -- curl <service-name>

    # RBAC
    kubectl apply -f rbac.yaml
    kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<ns>:<sa> -n <namespace>

    # ConfigMap / Secret
    kubectl get configmaps -n <namespace>
    kubectl get secret <name> -n <namespace> -o yaml
    [System.Convert]::FromBase64String("...")       decode secret value
    [System.Convert]::ToBase64String(...)            encode value (prove it's standard base64)

    # Ingress
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
    kubectl get ingress -n <namespace>
    kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80

    # NetworkPolicy
    kubectl apply -f networkpolicy.yaml
    kubectl run <test-pod> --image=curlimages/curl -n <namespace> --rm -it --restart=Never -- curl --max-time 5 <target>

---

## Issues Faced and Fixes
| Issue | Cause | Fix |
|-------|-------|-----|
| choco install failed - access denied | Not running PowerShell as Administrator | Reopen PowerShell as Administrator |
| docker-desktop choco package failed | Test-ProcessAdminRights cmdlet missing | Docker was already installed separately - ignored, used existing install |
| kind install failed via choco | Dependency (docker-desktop) failed first | Downloaded kind.exe directly via curl, moved to PATH manually |
| kind create cluster - docker info error | Docker Desktop not running | Started Docker Desktop, verified with docker info first |
| kubectl exec -- env failed | http-echo image has no shell/env binary (minimal image) | Used kubectl describe pod instead - reads from API, no shell needed |
| curl http://localhost:8080 blocked in PowerShell | Invoke-WebRequest security prompt for HTML parsing | Confirmed with [Y]es, or use -UseBasicParsing flag |
| NetworkPolicy did not block traffic | kindnet (kind's default CNI) does not enforce NetworkPolicy | Documented as known limitation - would work correctly on EKS/AKS or with Calico installed |
| kubectl apply "no objects passed" | Referenced a YAML file path that was never actually created | Created the file with Set-Content before applying |

---

## Interview Questions and Answers

Q1: What is the difference between a Deployment, ReplicaSet, and Pod?
A Pod is the smallest deployable unit - one or more containers sharing
network and storage. A ReplicaSet ensures a specified number of identical
Pods are running at all times, recreating any that die. A Deployment
manages ReplicaSets and adds rolling update and rollback capability on
top. In practice you only ever write Deployment YAML - it creates and
owns the ReplicaSet, which creates and owns the Pods. You never create
Pods directly in production.

Q2: How does Kubernetes self-healing actually work?
The Controller Manager continuously compares desired state (stored in
etcd, e.g. "3 replicas") against actual state (what's really running).
When a Pod dies, the ReplicaSet controller detects the count dropped
below desired and immediately schedules a replacement. I proved this
by manually deleting a pod and watching kubectl get pods show a brand
new pod with a different name appear within seconds, while the other
two original pods remained untouched.

Q3: What is the difference between a Pod IP and a Service IP?
Pod IPs come from the cluster's pod CIDR range (e.g. 10.244.0.0/16),
are assigned by the CNI plugin, and change every time a pod is recreated.
Service IPs come from a completely separate, virtual service CIDR range
(e.g. 10.96.0.0/16), are assigned once by the API server when the
Service is created, and never change. kube-proxy maintains iptables or
IPVS rules on every node mapping the virtual Service IP to whichever
real pod IPs are currently healthy. This is why applications should
always address each other by Service DNS name, never by pod IP.

Q4: Are Kubernetes Secrets encrypted?
No, by default Secrets are only base64-ENCODED, not encrypted. Encoding
is trivially reversible by anyone with no key required - I decoded one
myself in one line using standard base64 decoding with zero special
tools. For real protection you need to enable encryption-at-rest on
etcd, and ideally avoid storing raw secret values in plain YAML
altogether by using a tool like Sealed Secrets or External Secrets
Operator backed by AWS Secrets Manager, Azure Key Vault, or HashiCorp
Vault.

Q5: What is the difference between an Ingress resource and an Ingress Controller?
An Ingress is just a Kubernetes API object describing routing rules -
which path or host should go to which Service. By itself it does
nothing. An Ingress Controller is an actual running pod (commonly nginx
or traefik) that watches Ingress objects and performs the real traffic
forwarding. Writing Ingress YAML with no controller installed has zero
effect - this is a common mistake. kind does not ship a controller by
default, so I had to install ingress-nginx manually before any routing
worked.

Q6: Does Kubernetes enforce NetworkPolicy by default?
No, and this is a common misconception. By default every pod can reach
every other pod across all namespaces. NetworkPolicy is an opt-in API
object, and critically, enforcement entirely depends on the CNI plugin
in use. I proved this directly - I wrote a correct NetworkPolicy
restricting a namespace to only accept traffic from one other namespace,
but traffic from a disallowed namespace still got through, because
kind's default CNI (kindnet) does not implement NetworkPolicy enforcement
at all. CNIs like Calico, Cilium, and Azure CNI do enforce it. You must
verify your specific CNI supports enforcement before relying on
NetworkPolicy as an actual security boundary.

Q7: How do you debug a pod that has no shell available?
Many production images, especially minimal or distroless ones, have no
shell and no standard utilities, so kubectl exec -- sh or -- env will
fail with "executable file not found in PATH." The correct first step
is kubectl describe pod, which reads pod spec, resolved environment
variables, events, and status directly from the Kubernetes API without
needing anything installed inside the container. For deeper debugging
of shell-less containers, tools like kubectl debug (ephemeral containers)
or copying a debug sidecar are used instead.

Q8: How do ConfigMaps and Secrets get into a running container?
They are referenced inside the pod spec's env section using
configMapKeyRef or secretKeyRef, pulling a specific key's value in at
pod start time - never hardcoded into the image or Deployment YAML
directly. I verified this with kubectl describe pod, which showed the
Environment section correctly resolving each variable to its source
ConfigMap or Secret key, even though the actual secret value itself is
never displayed in describe or get output for security.
