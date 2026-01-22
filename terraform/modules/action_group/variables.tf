variable "resource_group_name" {
  description = "The name of the resource group in which to create the action group."
  type        = string
}

variable "action_group_name" {
  description = "The name of the action group."
  type        = string
}

variable "email_receiver" {
  description = "The email address to notify."
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources."
  type        = map(string)
  default     = {}
}
