GROUP             := udacity
NAME              := haproxy-consul
VERSION           ?= $(shell git rev-parse --short HEAD)
DOCKER_REPO       := udacity/$(NAME)
DOCKER_IMAGE      := $(DOCKER_REPO):$(VERSION)
DOCKER_RM         := $(shell echo $${DOCKER_RM:-true})
export

.PHONY: all build push

all: build

build:
	docker build --rm=$(DOCKER_RM) -t $(DOCKER_IMAGE) \
		--build-arg udacity_name=$(NAME) \
		--build-arg udacity_version=$(VERSION) \
		--build-arg udacity_git_url="$(shell git config --get remote.origin.url)" \
		--build-arg udacity_git_sha=$(shell git rev-parse HEAD) \
		--build-arg udacity_build_id=$(shell echo $$CIRCLE_BUILD_NUM) \
		--build-arg udacity_build_timestamp="$(shell date +"%d/%b/%Y:%H:%M:%S %z")" \
		--build-arg udacity_build_origin=$(shell echo $${CIRCLE_BUILD_NUM+circleci}) \
	.

push:
	@if ! docker images $(DOCKER_REPO) | awk '{ print $$2 }' | grep -q -F $(VERSION); then echo "$(DOCKER_IMAGE) is not yet built. Please run 'make build'"; false; fi
	docker push $(DOCKER_IMAGE)
