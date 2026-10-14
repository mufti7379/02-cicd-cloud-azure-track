variable "resource_group_name" {
  type        = string
  description = "Nama resource group."
}

variable "location" {
  type        = string
  description = "Region Azure resource group."
}

variable "tags" {
  type        = map(string)
  description = "Tag umum."
  default     = {}
}
