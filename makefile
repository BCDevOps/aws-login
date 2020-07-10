export ACCOUNT_ID := $(shell aws sts get-caller-identity 2>/dev/null | jq '.Account')

LAMBDA_INCLUDES = lambda/samlpost/index.js lambda/samlpost/index.html
BUILD_DIR = dist
lamba_samlpost.zip = $(BUILD_DIR)/lambda_samlpost.zip

package-lambda: $(lamba_samlpost.zip)
	@echo "Done."

$(lamba_samlpost.zip): $(LAMBDA_INCLUDES)
	@echo "Packaging lambda code..."
	-@mkdir $(BUILD_DIR)
	@zip -j $(lamba_samlpost.zip) $^

check_aws_login:
ifeq ($(ACCOUNT_ID),)
	$(error ACCOUNT_ID is not set)
endif
	@echo "AWS ACCOUNT_ID: '${ACCOUNT_ID}'"

deploy: $(lamba_samlpost.zip) check_aws_login
	@echo "Deploying app to AWS."
	@cd terraform/aws && terraform apply

add-org-read-role: check_aws_login
ifeq ($(MASTER_ACCOUNT_ID),)
	$(error MASTER_ACCOUNT_ID not set or does not match current logged in account)
endif
ifeq ($(CUSTOM_AUD),)
	$(error CUSTOM_AUD is not set)
endif
	@aws cloudformation deploy --template-file master_account_read_role.yaml --stack-name saml-read-role --parameter-overrides IDP=arn:aws:iam::$(MASTER_ACCOUNT_ID):saml-provider/BCGovKeyCloak CustomAud=$(CUSTOM_AUD) --capabilities CAPABILITY_NAMED_IAM

clean:
	-@rm -rf dist


