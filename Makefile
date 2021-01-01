.PHONY: fmt lint local-build shell terraform-bootstrap
local_run = docker-compose run --rm
tf_bootstrap = ${local_run} --workdir /usr/src/app/infra/bootstrap app terraform

fmt: local-build
	${tf_bootstrap} fmt

lint: local-build
	${tf_bootstrap} fmt -check
	${tf_bootstrap} validate

local-build: Dockerfile
	docker-compose build

shell: local-build
	${local_run} app bash

terraform-bootstrap: local-build
	${tf_bootstrap} apply
