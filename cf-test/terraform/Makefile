.DEFAULT_GOAL := help

.PHONY: up
up: ## Init, plan and apply tf
	terraform init
	terraform plan -out=plan.out
	terraform apply plan.out

.PHONY: down
down: ## plan and apply a tf destroy
	terraform plan -destroy -out=plan.out
	terraform apply plan.out

.PHONY: clean
clean: ## Remove .terraform folder, state and plan files
	rm -rf .terraform/
	rm plan.out
	rm terraform.tfstate*

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
