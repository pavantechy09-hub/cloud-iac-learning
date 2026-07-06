
---

## AIOps - K8sGPT + Ollama (Local AI)

### Setup
    K8sGPT v0.3.45 installed
    Ollama 0.6.4 with llama3.2:1b (1.3GB, runs locally)
    Model stored on E:\ollama-models\models
    Zero cost, zero internet calls for AI analysis

### Auth
    k8sgpt auth add --backend ollama --model llama3.2:1b --baseurl http://localhost:11434

### Healthy cluster scan
    k8sgpt analyze --explain --backend ollama
    ? AI Provider: ollama
    ? No problems detected

### Broken pod detection (proved hands-on)
    kubectl run broken-pod --image=nginx:doesnotexist123 -n accounts
    k8sgpt analyze --explain --backend ollama

    ? 0: Pod accounts/broken-pod()
       Error: failed to pull image nginx:doesnotexist123
       Image not found on Docker Hub
       Fix: correct the image name in your deployment spec

### What this proves
    K8sGPT scans Kubernetes resources automatically
    Sends findings to local LLM (llama3.2:1b via Ollama)
    Returns plain English explanation + root cause
    No data leaves your machine - fully private
    Enterprise pattern: replace OpenAI with Azure AI Foundry
    for compliance (PCI-DSS, GDPR) - data stays in your tenant

### Enterprise integration pattern
    Prometheus alert fires
      ? HolmesGPT receives alert automatically
      ? Fetches pod logs, events, metrics from K8s API
      ? Sends to LLM (Azure AI Foundry for compliance)
      ? Posts root cause + fix to Slack in 30 seconds
      ? SRE wakes up to diagnosis, not raw alert
      ? MTTR: 45 minutes ? 11 minutes
