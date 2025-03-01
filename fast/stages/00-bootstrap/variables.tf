/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

variable "billing_account" {
  description = "Billing account id and organization id ('nnnnnnnn' or null)."
  type = object({
    id              = string
    organization_id = number
  })
}

variable "bootstrap_user" {
  description = "Email of the nominal user running this stage for the first time."
  type        = string
  default     = null
}

variable "cicd_repositories" {
  # TODO: edit description once we add support for Cloud Build (null provider)
  description = "CI/CD repository configuration. Identity providers reference keys in the `federated_identity_providers` variable. Set to null to disable, or set individual repositories to null if not needed."
  type = object({
    bootstrap = object({
      branch            = string
      identity_provider = string
      name              = string
      type              = string
    })
    resman = object({
      branch            = string
      identity_provider = string
      name              = string
      type              = string
    })
  })
  default = null
  validation {
    condition = alltrue([
      for k, v in coalesce(var.cicd_repositories, {}) :
      v == null || (
        try(v.name, null) != null
        &&
        try(v.identity_provider, null) != null
      )
    ])
    error_message = "Non-null repositories need non-null name and providers."
  }
  validation {
    condition = alltrue([
      for k, v in coalesce(var.cicd_repositories, {}) :
      v == null || (
        contains(["github"], coalesce(try(v.type, null), "null"))
      )
    ])
    error_message = "Invalid repository type, supported types: 'github'."
  }
}

variable "custom_role_names" {
  description = "Names of custom roles defined at the org level."
  type = object({
    organization_iam_admin        = string
    service_project_network_admin = string
  })
  default = {
    organization_iam_admin        = "organizationIamAdmin"
    service_project_network_admin = "serviceProjectNetworkAdmin"
  }
}

variable "federated_identity_providers" {
  description = "Workload Identity Federation pools. The `cicd_repositories` variable references keys here."
  type = map(object({
    attribute_condition = string
    issuer              = string
  }))
  default  = {}
  nullable = false
}

variable "groups" {
  # https://cloud.google.com/docs/enterprise/setup-checklist
  description = "Group names to grant organization-level permissions."
  type        = map(string)
  default = {
    gcp-billing-admins      = "gcp-billing-admins",
    gcp-devops              = "gcp-devops",
    gcp-network-admins      = "gcp-network-admins"
    gcp-organization-admins = "gcp-organization-admins"
    gcp-security-admins     = "gcp-security-admins"
    gcp-support             = "gcp-support"
  }
}

variable "iam" {
  description = "Organization-level custom IAM settings in role => [principal] format."
  type        = map(list(string))
  default     = {}
}

variable "iam_additive" {
  description = "Organization-level custom IAM settings in role => [principal] format for non-authoritative bindings."
  type        = map(list(string))
  default     = {}
}

# See https://cloud.google.com/architecture/exporting-stackdriver-logging-for-security-and-access-analytics
# for additional logging filter examples
variable "log_sinks" {
  description = "Org-level log sinks, in name => {type, filter} format."
  type = map(object({
    filter = string
    type   = string
  }))
  default = {
    audit-logs = {
      filter = "logName:\"/logs/cloudaudit.googleapis.com%2Factivity\" OR logName:\"/logs/cloudaudit.googleapis.com%2Fsystem_event\""
      type   = "bigquery"
    }
    vpc-sc = {
      filter = "protoPayload.metadata.@type=\"type.googleapis.com/google.cloud.audit.VpcServiceControlAuditMetadata\""
      type   = "bigquery"
    }
  }
  validation {
    condition = alltrue([
      for k, v in var.log_sinks :
      contains(["bigquery", "logging", "pubsub", "storage"], v.type)
    ])
    error_message = "Type must be one of 'bigquery', 'logging', 'pubsub', 'storage'."
  }
}

variable "organization" {
  description = "Organization details."
  type = object({
    domain      = string
    id          = number
    customer_id = string
  })
}

variable "outputs_location" {
  description = "Enable writing provider, tfvars and CI/CD workflow files to local filesystem. Leave null to disable"
  type        = string
  default     = null
}

variable "prefix" {
  description = "Prefix used for resources that need unique names. Use 9 characters or less."
  type        = string

  validation {
    condition     = try(length(var.prefix), 0) < 10
    error_message = "Use a maximum of 9 characters for prefix."
  }
}
