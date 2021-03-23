# AWS Login

This repo contains code for an replacement AWS login page that provides a facility to both access the AWS web console, and access temporary credentials for use with AWS command-line tools.

## Why would I want this?

You might want this if you don't use AWS IAM users, but have an AWS SAML SSO set up that provides for convenient and secure, role-based interactive access to the AWS web console, but you also want to be able to use command line tools to interact with your AWS accounts.  Without this login page (or alternative) you won't be able to get credentials to provide to command tools.  

### Prerequisites/Assumptions

This login page is only going to be useful if you have a one or more AWS accounts with one or more roles each, accessible via a SAML SSO provider.  If you see a screen like the one below when you login to the AWS web console, this might be useful to you.  In fact, this login page provides a replacement for the screen below.

![AWS Login](images/aws_sso_login.png)


# Build Steps

1. Get credentials for target AWS root account and apply to current shell (or use AWS profile, etc.). (Note: [this](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-role.html#cli-configure-role-xaccount) might be helpful if you want to use an IAM user from the master account + cross-account role.

2. Execute Terraform against target account:

```shell script
terraform plan
terraform apply -var="resource_name_suffix=<mysuffix>" -var="keycloak_saml_name=<idp name>"
```

> Example: terraform apply -var="resource_name_suffix=prod" -var="keycloak_saml_name=BCGovKeyCloak-xyz123"

> _Note_:  You will also be prompted to confirm the `apply` command. Type "yes" when prompted.

3.  Update Roles' Trust Permissions
- Update all Roles' Trust Permission to include an addition SAML:aud value. This value should be the URL endpoint output from the previous step.
- Note: This may be done as part of landing zone code.

4. [Optional] Assign org read role ro users within the IdP (e.g. KeyCloak) to allow access to account metadata, and display of it on the login page. 

> Note: Although this step is optional and the login app will work without it, you may see errors in the Javascript console without it.  

This can be done manually, or - preferably - using automation via Terraform.  The form of the role to assign in the IdP will likely be be `<IDP_ARN>,<ROLE_ARN>`.

## Getting Help or Reporting an Issue

If you have questions about this tool, a suggestion, or find a bug, please [Create an Issue](https://github.com/BCDevOps/aws-saml2sts-bookmarklet/issues/new).


## License
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](./LICENSE)


## Technical Details

Once deployed and access by a user as part of their login flow, the page retrieves a set of temporary credentials that can be used in on the command line to interact with the AWS.        

## Dependencies

### Runtime
* jQuery (MIT) ![License](https://img.shields.io/badge/License-MIT-green.svg)
* jQuery UI (MIT) ![License](https://img.shields.io/badge/License-MIT-green.svg)
* AWS Javascript client library ![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)

## Project Status
- [x] Development
- [ ] Beta
- [ ] Production/Maintenance

## Documentation

You're looking at it :)

## Security

This login page provides an alternative to browser mechanisms ("userscripts") and local scripts to retrieve temporary credentials.  Code executes within the user's browser, invoking the AWS API over a secure HTTPS connection when retrieving temporary credentials.  If the user chooses to log in to the console, server-side code will be executed that retrieves a web console token.  All code executes only when explicitly invoked by the user.

## How to Contribute
 
If you would like to contribute, please see our [CONTRIBUTING](CONTRIBUTING.md) guidelines.

Please note that this project is released with a [Contributor Code of Conduct](CODE_OF_CONDUCT.md). 
By participating in this project you agree to abide by its terms.
