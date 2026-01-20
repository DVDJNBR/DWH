variable "dashboard_name" {
  description = "The name of the dashboard."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group in which to create the dashboard."
  type        = string
}

variable "location" {
  description = "The Azure region where the dashboard will be created."
  type        = string
}

variable "stream_analytics_job_id" {
  description = "The resource ID of the Stream Analytics job to monitor."
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources."
  type        = map(string)
  default     = {}
}
