# 01 — Infra (Jaringan + VM Jenkins + AKS) — Terragrunt + Terraform

**Prereq:** 00-bootstrap (storage account state siap, resource provider terdaftar, identity Terraform tersedia). Login `az login`.

## Tujuan
Provisioning jaringan, VM Jenkins, AKS, ACR, PostgreSQL, dan Key Vault di Azure memakai **Terraform modules** yang dirangkai **Terragrunt** dengan **state terpisah per component**.

## Kenapa Terragrunt (bukan satu root Terraform)
Masalah pada satu root monolitik:
- Ubah 1 komponen → `plan/apply` tetap men-scan SEMUA resource → lambat.
- Comment satu `module` block → Terraform menganggapnya "hapus" → **destroy berbahaya**.

Solusi di sini: setiap **component** punya state sendiri (di-generate Terragrunt), tapi tetap bisa di-apply sekaligus via `run-all`.

## Struktur

```
01-infra/
├── terragrunt.hcl                  # ROOT: generate backend.tf (azurerm) + provider.tf (state per-component)
├── modules/                        # Terraform murni, reusable
│   ├── resource-group/             # Wadah resource per environment
│   ├── network/                    # VNet + subnet + NAT Gateway + NSG/ASG + private DNS PostgreSQL
│   ├── compute/                    # VM Jenkins (IP publik reserved, SSH dibatasi NSG)
│   ├── aks/                        # AKS (CNI Overlay + Cilium, Workload Identity, Entra ID RBAC)
│   ├── acr/                        # Azure Container Registry + cleanup terjadwal
│   ├── postgres/                   # PostgreSQL Flexible Server (private access, Entra ID auth)
│   └── keyvault/                   # Key Vault + key untuk Vault auto-unseal
└── environments/
    └── dev/
        ├── env.hcl                 # Nilai per-env (subscription, location, zone, RG, state)
        ├── resource-group/         # unit pertama — semua unit lain bergantung padanya
        ├── network/                # dependency → resource-group
        ├── compute/                # dependency → network
        ├── aks/                    # dependency → network
        ├── acr/                    # dependency → aks, compute (AcrPull/AcrPush)
        ├── postgres/               # dependency → network, aks
        └── keyvault/               # dependency → aks
```

## Pemetaan GCP → Azure
| GCP | Azure |
|-----|-------|
| Project | Resource group (`resource-group`) |
| VPC + secondary range | VNet + subnet per peran; pod/service CIDR overlay di AKS |
| Cloud NAT | NAT Gateway (subnet AKS) |
| Firewall + network tags | NSG + Application Security Group |
| IAP SSH | NSG SSH hanya dari `ssh_allowed_cidrs` (+ opsional Entra ID SSH login) |
| Service account VM/node | User-assigned managed identity / kubelet identity |
| GKE | AKS |
| Artifact Registry | ACR |
| Cloud SQL + PSA | PostgreSQL Flexible Server + subnet delegated + Private DNS |
| Cloud KMS | Key Vault |
| Workload Identity (GSA↔KSA) | Federated identity credential (OIDC issuer AKS) |

## Cara pakai

1. Edit `environments/dev/env.hcl`: isi `subscription_id`, `location`, `zone`, `resource_group_name`, dan `state_*` (dari output stage 00).
2. Ganti nama yang harus **unik global**: `registry_name` (acr), `instance_name` (postgres), `key_vault_name` (keyvault).
3. Isi IP admin di `ssh_allowed_cidrs` & `webhook_allowed_cidrs` (network).
4. Siapkan SSH key: default `~/.ssh/id_ed25519.pub` (override: `export SSH_PUBLIC_KEY_PATH=...`).
5. Password PostgreSQL: `export TF_VAR_standard_db_password='...'` (tidak disimpan di repo).

**Apply semua sekaligus (urutan otomatis dari dependency):**
```bash
cd environments/dev
terragrunt run-all apply
```

**Apply / ubah SATU component saja (cepat, aman):**
```bash
cd environments/dev/compute
terragrunt apply        # hanya menyentuh state compute
```

**Tidak ingin sebuah component di-apply?** Cukup jangan jalankan folder-nya — TIDAK ada risiko destroy seperti saat meng-comment module di root monolitik.

**Dari Jenkins/CI** (tanpa `az login`): `export ARM_USE_MSI=true ARM_CLIENT_ID=<terraform_identity_client_id>` — dibaca otomatis oleh backend & provider.

## Verifikasi
- Format HCL: `terragrunt hclfmt --check` (dari `01-infra/`).
- Validasi modul: `cd modules/<m> && terraform init -backend=false && terraform validate`.
- Graph dependency: `cd environments/dev && terragrunt graph-dependencies`.
- SSH VM: `cd environments/dev/compute && terragrunt output ssh_command`.
- kubectl: `cd environments/dev/aks && terragrunt output get_credentials_command` → `kubectl get nodes`.

## Teardown
- Matikan dulu proteksi: `prevent_destroy` di module terkait + policy `denyAction` di 00-bootstrap (`enable_terraform_destroy_deny=false`).
- Semua: `cd environments/dev && terragrunt run-all destroy`.
- Satu component: `cd environments/dev/<component> && terragrunt destroy`.

## Catatan biaya (perkiraan, cek Azure Pricing Calculator)
- VM `Standard_D2as_v5` Spot: ~$10–25/bln saat running (on-demand ~$70/bln).
- AKS control plane tier Free: gratis; node `Standard_B2s`: ~$35/bln per node.
- NAT Gateway: ~$33/bln + data. Public IP Standard: ~$4/bln per IP.
- ACR Basic: ~$5/bln. PostgreSQL `B_Standard_B1ms`: ~$15–20/bln. Key Vault: per operasi (nyaris nol).
- Log Analytics (control plane logs): per GB ingest, dibatasi 1 GB/hari. VNet/subnet/NSG: gratis.

> **AD-9:** modul Azure-specific terpisah dari unit Terragrunt → varian Local track (kind) dapat diselipkan tanpa membongkar modul.
