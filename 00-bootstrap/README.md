# 00 — Bootstrap

**Prereq:** Onboarding (akun Azure aktif dengan subscription, role **Owner** di subscription, `az` & `terraform >= 1.7` terpasang, login `az login`).

## Tujuan
Menyiapkan fondasi Azure untuk seluruh course:
- Mendaftarkan **resource provider** yang dibutuhkan (padanan enable API di GCP).
- Membuat **storage account + container** untuk **remote state** (versioning + soft delete aktif).
- Membuat **managed identity Terraform** untuk Jenkins/CI di stage berikutnya (tanpa secret/key file).
- Memasang **Azure Policy `denyAction`** yang memblokir delete resource stateful (VNet, VM, AKS, storage account).

> **Penting (chicken-and-egg):** stage ini MEMBUAT storage account state, jadi ia berjalan dengan **local state** (tidak ada blok `backend "azurerm"`). Stage berikutnya barulah memakai backend azurerm — lihat `backend.tf.example`.

## Pemetaan GCP → Azure
| GCP | Azure |
|-----|-------|
| `google_project_service` | `resource_providers_to_register` di `provider.tf` |
| Bucket GCS state | Storage account + blob container `tfstate` |
| Service account + impersonation | User-assigned managed identity; user lokal pakai `az login` + Storage Blob Data Contributor |
| `roles/*` project | `Contributor` + `Role Based Access Control Administrator` (dibatasi ABAC condition) |
| IAM Deny Policy | Azure Policy `denyAction` (berlaku untuk semua principal) |

## Langkah
1. `az login` lalu `az account set --subscription <SUBSCRIPTION_ID>`
2. `cp terraform.tfvars.example terraform.tfvars`
3. Isi `subscription_id`, `location`, dan `state_storage_account_name` (3-24 huruf kecil/angka, unik global).
4. `terraform init`
5. `terraform plan`
6. `terraform apply`

## Verifikasi
- `terraform fmt -check` dan `terraform validate` lulus.
- Output `state_storage_account_name` dan `terraform_identity_client_id` muncul.
- Storage account terlihat di `az storage account list -o table`.
- Resource provider terdaftar: `az provider list --query "[?registrationState=='Registered'].namespace" -o tsv`.
- Policy aktif: `az policy assignment list --query "[].name" -o tsv` (efek denyAction butuh hingga ~30 menit).

## Memakai output di stage berikutnya
Salin pola `backend.tf.example` ke `backend.tf` pada stage `01-infra` (dst.), isi `resource_group_name`, `storage_account_name`, `container_name` dari output stage ini, dan `key` unik per stage. Dari Jenkins/CI, tambahkan `use_msi = true` + `client_id = terraform_identity_client_id`.

## Teardown
1. Matikan policy: `terraform apply -var="enable_terraform_destroy_deny=false"` lalu tunggu ~30 menit.
2. Comment blok `lifecycle { prevent_destroy = true }` pada storage account & container di `main.tf`.
3. `./teardown.sh` — jalankan **hanya** setelah seluruh stage lain di-teardown (ini menghapus storage account state beserta isinya).

## Catatan biaya
- Storage account Standard LRS (state berukuran KB): biaya mendekati nol. Managed identity, role assignment, dan Azure Policy: gratis. Aman untuk free account.
