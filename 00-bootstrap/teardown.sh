#!/usr/bin/env bash
set -euo pipefail

# Teardown stage 00-bootstrap.
# PERINGATAN: jalankan HANYA setelah seluruh stage lain sudah di-teardown,
# karena ini menghapus storage account state yang dipakai stage berikutnya.

cd "$(dirname "$0")"

echo ">> Menghancurkan resource stage 00-bootstrap..."
echo ">> Pastikan tidak ada stage lain yang masih memakai storage account state ini."

# Storage account & container state diproteksi prevent_destroy + policy denyAction.
# Matikan keduanya dulu (lihat README bagian Teardown), baru jalankan destroy.
terraform destroy "$@"

echo ">> Selesai. Verifikasi tidak ada resource yatim dengan: az group list -o table"
