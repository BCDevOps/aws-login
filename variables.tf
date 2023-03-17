variable "lambda_name" {
  description = "The name of the created lambda function"
  type        = string
  default     = "LoginApp_saml_lambda"
}

variable "keycloak_saml_name" {
  description = "The name of an (existing) Keycloak IDP in the root account that will be referenced when assuming the role used to read account metadata.  It generally will be suffixed with an alphanumeric discriminator (corresponding to a KeyCloak realm) since more than one IDP may exist."
  default     = "BCGovKeyCloak"
}

variable "resource_name_suffix" {
  description = "a value to append to resource names to keep them distinct if there may be more than one instance of the same resource (e.g. multiple workspaces applying to same account). Example values would be 'prod' or 'test'"
  type        = string
  default     = ""
}

variable "kc_base_url" {
  description = "The base URL for the Keycloak domain, does not include https://"
  type        = string
  default     = ""
}

variable "kc_realm" {
  description = "The name name of your Keycloak realm"
  type        = string
  default     = ""
}

variable "kc_terraform_auth_client_id" {
  description = "The ID of the keycloak client used for terraform automation"
  type        = string
  default     = ""
}

variable "kc_terraform_auth_client_secret" {
  description = "The authentication secret of the keycloak client used for terraform automation"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Domain name of the login app"
  type        = string
}
