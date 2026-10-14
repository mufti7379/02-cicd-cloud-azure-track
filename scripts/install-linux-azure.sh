#!/usr/bin/env bash
# =============================================================================
# install-linux.sh — One-liner Installer untuk Ubuntu/Debian (& WSL2)
# Be A DevOps Engineer: GCP Cloud Track
#
# Usage: ./scripts/install-linux.sh
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_step() { echo -e "\n${BLUE}${BOLD}▶ $1${NC}"; }
log_ok()   { echo -e "  ${GREEN}✅ $1${NC}"; }
log_skip() { echo -e "  ${YELLOW}⏭  $1 (sudah ada — skip)${NC}"; }
log_fail() { echo -e "  ${RED}❌ ERROR: $1${NC}"; exit 1; }

# ─── Cek OS ──────────────────────────────────────────────────────────────────
if [[ "$OSTYPE" != "linux"* ]]; then
  log_fail "Script ini hanya untuk Linux / WSL2. Gunakan install-mac-as.sh untuk macOS."
echo "  1. Azure CLI (az) + kubectl + kubelogin"
fi

if ! command -v apt-get &>/dev/null; then
  log_fail "Script ini hanya untuk distribusi berbasis apt (Ubuntu/Debian/WSL2)."
fi

ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  BINARY_ARCH="amd64" ;;
  aarch64) BINARY_ARCH="arm64" ;;
  *) log_fail "Arsitektur tidak didukung: $ARCH" ;;
esac

IS_WSL=false
if grep -qi microsoft /proc/version 2>/dev/null; then
  IS_WSL=true
fi

echo ""
echo -e "${BOLD}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Be A DevOps Engineer — GCP Cloud Track Linux/WSL2 Installer       ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Target: Linux ${ARCH} $([ "$IS_WSL" = true ] && echo '(WSL2 environment)')"
echo -e "  Tool yang akan diinstall:"
# echo -e "  1. Google Cloud SDK (gcloud CLI + gke-gcloud-auth-plugin)"
echo -e "  2. Terraform"
echo -e "  3. Terragrunt"
echo -e "  4. kubectl & Helm"
echo -e "  5. Kustomize"
echo -e "  6. Ansible & Python3"
echo -e "  7. ArgoCD CLI & kubectl argo-rollouts"
echo ""
read -r -p "  Lanjutkan instalasi otomatis? (y/N): " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Dibatalkan."; exit 0; }

# ─── 0. Dependencies ─────────────────────────────────────────────────────────
log_step "0/7 — System Update & Base Packages"
sudo apt-get update -q
sudo apt-get install -y -q curl wget git apt-transport-https ca-certificates gnupg lsb-release python3 python3-pip python3-venv jq
log_ok "Base packages siap"

# ─── 1. Google Cloud SDK ─────────────────────────────────────────────────────
# log_step "1/7 — Google Cloud SDK (gcloud)"
# if command -v gcloud &>/dev/null; then
  # log_skip "gcloud $(gcloud version 2>/dev/null | head -1)"
# else
  # echo "  Menambahkan repositori Google Cloud..."
#   sudo mkdir -p /etc/apt/keyrings
  # curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/google-cloud.gpg --yes
  # echo "deb [signed-by=/etc/apt/keyrings/google-cloud.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
#   sudo apt-get update -q
  # sudo apt-get install -y -q google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin kubectl
  # log_ok "Google Cloud SDK terinstall"
# fi
# ─── 1. Azure CLI + kubectl + kubelogin ─────────────────────────────────────
log_step "1/7 — Azure CLI (az) + kubectl + kubelogin"
if command -v az &>/dev/null; then
  log_skip "az $(az version --query '"azure-cli"' -o tsv 2>/dev/null)"
else
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
  log_ok "Azure CLI terinstall"
fi
if ! command -v kubectl &>/dev/null || ! command -v kubelogin &>/dev/null; then
  sudo az aks install-cli
  log_ok "kubectl + kubelogin terinstall"
else
  log_skip "kubectl & kubelogin sudah ada"
fi

# ─── 2. Terraform ────────────────────────────────────────────────────────────
log_step "2/7 — HashiCorp Terraform"
if command -v terraform &>/dev/null; then
  log_skip "Terraform $(terraform version | head -1)"
else
  echo "  Menambahkan repositori HashiCorp..."
  wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg --yes
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
  sudo apt-get update -q
  sudo apt-get install -y -q terraform
  log_ok "Terraform terinstall"
fi

# ─── 3. Terragrunt ───────────────────────────────────────────────────────────
log_step "3/7 — Terragrunt"
if command -v terragrunt &>/dev/null; then
  log_skip "Terragrunt $(terragrunt --version | head -1)"
else
  echo "  Downloading Terragrunt binary..."
  TG_VERSION=$(curl -s https://api.github.com/repos/gruntwork-io/terragrunt/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  sudo curl -fsSL -o /usr/local/bin/terragrunt "https://github.com/gruntwork-io/terragrunt/releases/download/${TG_VERSION}/terragrunt_linux_${BINARY_ARCH}"
  sudo chmod +x /usr/local/bin/terragrunt
  log_ok "Terragrunt ${TG_VERSION} terinstall"
fi

# ─── 4. Helm ─────────────────────────────────────────────────────────────────
log_step "4/7 — Helm"
if command -v helm &>/dev/null; then
  log_skip "Helm $(helm version --short 2>/dev/null || echo 'ready')"
else
  echo "  Menginstall Helm via get-helm-3 script..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  log_ok "Helm terinstall"
fi

# ─── 5. Kustomize ────────────────────────────────────────────────────────────
log_step "5/7 — Kustomize"
if command -v kustomize &>/dev/null; then
  log_skip "Kustomize $(kustomize version 2>/dev/null || echo 'ready')"
else
  echo "  Menginstall Kustomize binary..."
  curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
  sudo mv kustomize /usr/local/bin/
  log_ok "Kustomize terinstall"
fi

# ─── 6. Ansible ──────────────────────────────────────────────────────────────
log_step "6/7 — Ansible"
if command -v ansible &>/dev/null; then
  log_skip "Ansible $(ansible --version | head -1)"
else
  echo "  Menginstall Ansible via pip3/apt..."
  sudo apt-get install -y -q ansible || pip3 install --user ansible
  log_ok "Ansible terinstall"
fi

# ─── 7. ArgoCD CLI & kubectl argo-rollouts ───────────────────────────────────
log_step "7/7 — ArgoCD CLI & kubectl argo-rollouts"
if command -v argocd &>/dev/null; then
  log_skip "ArgoCD CLI $(argocd version --client --short 2>/dev/null || echo 'ready')"
else
  echo "  Downloading ArgoCD CLI binary..."
  sudo curl -fsSL -o /usr/local/bin/argocd "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-${BINARY_ARCH}"
  sudo chmod +x /usr/local/bin/argocd
  log_ok "ArgoCD CLI terinstall"
fi

if kubectl argo rollouts version &>/dev/null 2>&1; then
  log_skip "kubectl argo-rollouts plugin"
else
  echo "  Downloading kubectl-argo-rollouts binary..."
  sudo curl -fsSL -o /usr/local/bin/kubectl-argo-rollouts "https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-${BINARY_ARCH}"
  sudo chmod +x /usr/local/bin/kubectl-argo-rollouts
  log_ok "kubectl argo-rollouts plugin terinstall"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║  🎉 SEMUA TOOLS CLOUD TRACK TELAH BERHASIL DIINSTALL DI LINUX/WSL! ║${NC}"
echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Verifikasi cepat:"
# echo -e "  • gcloud:     $(which gcloud || echo 'not found')"
echo -e "  • terraform:  $(which terraform || echo 'not found')"
echo -e "  • terragrunt: $(which terragrunt || echo 'not found')"
echo -e "  • kubectl:    $(which kubectl || echo 'not found')"
echo -e "  • helm:       $(which helm || echo 'not found')"
echo -e "  • kustomize:  $(which kustomize || echo 'not found')"
echo -e "  • ansible:    $(which ansible || echo 'not found')"
echo -e "  • argocd:     $(which argocd || echo 'not found')"
echo ""
echo -e "  Langkah berikutnya: Login ke akun GCP Anda:"
# echo -e "  ${BOLD}gcloud auth login${NC}"
# echo -e "  ${BOLD}gcloud auth application-default login${NC}"
echo ""
