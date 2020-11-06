variable keycloak_saml_name{
    description = "Keycloak IDP Name"
    default     = "BCGovKeyCloak"
}

variable master_account_id {
    description = "Master AWS Account Id"
}

variable "resource_name_suffix" {
	description = "a value to append to resource names to keep them distinct if there may be more than one instnace of the same resrouce (e.g. multiple workspaces applying to same account)"
	type = 	string
	default = ""
}
