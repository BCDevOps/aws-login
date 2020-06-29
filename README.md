# AWS Login

This repo contains code for an AWS login tha provides a facility to both access the AWS web console, and access temporary crednetials for use with AWS command-line  tools.  

# Build Steps

## 1 - Lambda (Skip if no changes to lambda or static html code)
Zip up the two files into `lambda_samlpost.zip` and store in the `builds\` folder.
Example: 
```
cd lambda/samlpost
zip ../../builds/lambda_samlpost.zip index.js index.html
```

## 2 - Terraform
Deploy the Terraform to AWS. 

## 3 - Update Roles
Update all Roles' Trust Permission to include an addition SAML:aud value. This value should be the URL endpoint output from the previous step.

