# AWS Login

This repo contains code for an replacement AWS login page that provides a facility to both access the AWS web console, and access temporary credentials for use with AWS command-line tools.

## Why would I want this?

You might want this if you don't use AWS IAM users, but have an AWS SAML SSO set up that provides for convenient and secure, role-based interactive access to the AWS web console, but you also want to be able to use command line tools to interact with your AWS accounts.  Without this login page (or alternative) you won't be able to get credentials to provide to command tools.  

### Prerequisites/Assumptions

This login page is only going to be useful if you have a one or more AWS accounts with one or more roles each, accessible via a SAML SSO provider.  If you see a screen like the one below when you login to the AWS web console, this might be useful to you.  In fact, this login page provides a replacement for the screen below.

![AWS Login](images/aws_sso_login.png)


# Build Steps

1. Package Lambda (Skip if no changes to lambda or static html code)
- Zip up the two files into `lambda_samlpost.zip` and store in the `builds\` folder.
Example: 
```
cd lambda/samlpost
zip ../../builds/lambda_samlpost.zip index.js index.html
```

1. Execute Terraform against target accoun
Deploy the Terraform to AWS. 

1.  Update Roles' Trust Permissions
- Update all Roles' Trust Permission to include an addition SAML:aud value. This value should be the URL endpoint output from the previous step.


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
