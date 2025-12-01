variable "project_name" {
  description = "Project name for repository naming"
  type        = string
}

variable "image_retention_count" {
  description = "Number of images to retain per repository"
  type        = number
  default     = 10
}
