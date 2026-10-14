terraform {
  required_version = ">= 1.7"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # CATATAN (chicken-and-egg):
  # Stage 00-bootstrap inilah yang MEMBUAT storage account state. Karena itu stage ini
  # sengaja TIDAK memakai blok `backend "azurerm"` — ia berjalan dengan local state.
  # Setelah storage account terbuat, stage berikutnya (01-infra, dst.) memakai backend
  # azurerm mengikuti contoh di backend.tf.example.
}
