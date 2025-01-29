variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "octopus"
}

variable "region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "eu-central-1"
}

variable "codefresh_account_id" {
  description = "The Codefresh account ID"
  type        = string
}

variable "codefresh_user_token" {
  description = "The user token generated in Codefresh UI"
  type        = string
}

variable "github_username" {
  description = "The GitHub username"
  type        = string
}

variable "github_token" {
  description = "The GitHub token"
  type        = string
}