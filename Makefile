TF_DIR=infra/terraform
TF_VARS?=dev.tfvars

.PHONY: tf-init tf-plan tf-apply tf-destroy fmt function-venv function-test frontend-install frontend-build

tf-init:
	cd $(TF_DIR) && terraform init

tf-plan:
	cd $(TF_DIR) && terraform plan -var-file=$(TF_VARS)

tf-apply:
	cd $(TF_DIR) && terraform apply -auto-approve -var-file=$(TF_VARS)

tf-destroy:
	cd $(TF_DIR) && terraform destroy -auto-approve -var-file=$(TF_VARS)

fmt:
	cd $(TF_DIR) && terraform fmt

function-venv:
	python3 -m venv .venv && . .venv/bin/activate && pip install --upgrade pip && pip install -r function_app/requirements.txt

function-test:
	. .venv/bin/activate && pytest function_app

frontend-install:
	cd frontend && npm install

frontend-build:
	cd frontend && npm run build
