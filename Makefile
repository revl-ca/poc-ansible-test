default: help

TEST_DOCKER_CONTAINER_NAME ?= ansible-test-ubuntu
LINT_DOCKER_CONTAINER_NAME ?= yamllint-test

start-test-container:
	docker container run -d --rm --privileged --name ${TEST_DOCKER_CONTAINER_NAME} -p 5000:22 ${TEST_DOCKER_CONTAINER_NAME}

stop-test-container:
	docker container stop ${TEST_DOCKER_CONTAINER_NAME} || true

apply-playbook-once:
	ansible-playbook -i inventory test.yml

apply-playbook-twice:
	(unbuffer ansible-playbook -i inventory test.yml | tee /dev/tty | grep -q 'changed=0.*failed=0' && echo -e '\n[\e[32mOK\e[0m] The playbook is idempotent.') || (echo -e '\n[\e[31mERROR\e[0m] The playbook is **NOT** idempotent.' && exit 1)

.PHONY: test
test: stop-test-container start-test-container apply-playbook-once apply-playbook-twice stop-test-container ## [TEST] Test Ansible Idempotency.

.PHONY: lint
lint: ## [LINT] Lint YAML files.
	docker run --rm -it \
		-v ${PWD}:/yaml \
		--workdir /yaml \
		${LINT_DOCKER_CONTAINER_NAME} yamllint .

.PHONY: build
build: ## [DOCKER] Build required images.
	docker image build -t ${TEST_DOCKER_CONTAINER_NAME} -f Dockerfile.test-ubuntu .
	docker image build -t ${LINT_DOCKER_CONTAINER_NAME} -f Dockerfile.yamllint .

.PHONY: clean
clean: stop-test-container  ## [DOCKER] Clean images.
	docker image rm ${TEST_DOCKER_CONTAINER_NAME} --force
	docker image rm ${LINT_DOCKER_CONTAINER_NAME} --force

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN { FS = ":.*?## " }; { printf "\033[36m%-15s\033[0m %s\n", $$1, $$2 }'

check_defined = $(strip $(foreach 1,$1, $(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = $(if $(value $1),, $(error Undefined $1$(if $2, ($2))))

