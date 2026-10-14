provider "azurerm" {
  subscription_id = var.subscription_id

  # Padanan "enable API" di GCP: resource provider didaftarkan eksplisit saat provider
  # init, BUKAN sebagai resource di state. Jadi destroy tidak pernah meng-unregister
  # provider (setara disable_on_destroy = false) — teardown tidak melumpuhkan subscription.
  resource_provider_registrations = "none"
  resource_providers_to_register  = var.resource_providers

  features {}
}
