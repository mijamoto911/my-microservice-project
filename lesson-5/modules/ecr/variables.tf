variable "repository_name" {
  description = "Name of the ECR repository (lowercase, may include '/', '-', '_', '.')"
  type        = string

  validation {
    condition = (
      length(var.repository_name) > 0 &&
      can(regex("^[a-z0-9](?:[a-z0-9._/-]*[a-z0-9])?$", var.repository_name))
    )
    error_message = "repository_name must be lowercase, start/end with [a-z0-9], and only contain a-z, 0-9, '/', '.', '_', '-'."
  }
}

variable "image_tag_mutability" {
  description = "Whether image tags are MUTABLE or IMMUTABLE."
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be either 'MUTABLE' or 'IMMUTABLE'."
  }
}

variable "force_delete" {
  description = "Force delete the repository even if it contains images."
  type        = bool
  default     = true
}

variable "image_scan_on_push" {
  description = "Enable ECR image scanning on push."
  type        = bool
  default     = true
}

variable "allowed_principals" {
  description = "List of AWS principals (ARNs) allowed to pull images cross-account."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for arn in var.allowed_principals : can(regex("^arn:aws(-[a-z]+)?:iam::[0-9]{12}:(root|role\\/.+|user\\/.+)$", arn))])
    error_message = "Each item in allowed_principals must be a valid IAM ARN (account root, role, or user)."
  }
}

variable "repository_policy" {
  description = "Optional full JSON policy to override the generated repository policy."
  type        = string
  default     = null

  validation {
    condition     = var.repository_policy == null ? true : can(jsondecode(var.repository_policy))
    error_message = "repository_policy must be valid JSON when provided."
  }
}

variable "tags" {
  description = "Additional tags to apply to the ECR repository."
  type        = map(string)
  default     = {}
}
