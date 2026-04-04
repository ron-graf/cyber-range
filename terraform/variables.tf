variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "ssh_pub_key_file" {
  description = "Path to SSH public key for VM access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_user" {
  description = "SSH username for VM access"
  type        = string
  default     = "ranger"
}

variable "use_spot" {
  description = "Use spot/preemptible VMs to reduce cost"
  type        = bool
  default     = true
}
