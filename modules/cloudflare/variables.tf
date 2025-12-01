variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID (for Worker deployment)"
  type        = string
}

variable "domain_name" {
  description = "Root domain (e.g., example.com)"
  type        = string
}

variable "frontend_url" {
  description = "S3 website endpoint URL (http://...)"
  type        = string
}

variable "backend_url" {
  description = "ALB DNS URL (http://...)"
  type        = string
}
