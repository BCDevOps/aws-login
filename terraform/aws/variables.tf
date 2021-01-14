variable keycloak_saml_name{
    description = "The name of an (existing) Keycloak IDP in the root account that will be referenced when assuming the role used to read account metadata.  It generally will be suffixed with an alphanumeric discriminator (corresponding to a KeyCloak realm) since more than one IDP may exist."
    default     = "BCGovKeyCloak"
}

variable master_account_id {
    description = "Master AWS Account Id"
}

variable "resource_name_suffix" {
	description = "a value to append to resource names to keep them distinct if there may be more than one instance of the same resource (e.g. multiple workspaces applying to same account). Example values would be 'prod' or 'test'"
	type = 	string
	default = ""
}
