
# Which version of prototool should be used.
DOCKER_PROTOTOOL_VERSION=1.8.1
# Include these go module requirements when creating a brand new go repo.
# These should probably change when prototool/protoc version is changed.
GO_MOD_REQUIREMENTS=github.com/golang/protobuf@v1.3.1 google.golang.org/grpc@v1.19.1

# include the list of rendered repositories.
include rendered_repos.mk

# force bash because a few things depend on it and on linux bash != sh
SHELL := /bin/bash

REPO_DIR = build/repos
REPO_DIRS = $(REPOS:%=$(REPO_DIR)/%)
REPO_READMES = $(REPO_DIRS:%=%/README.md)
MAKEFILE_DIR = $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
ABS_MAKEFILE_DIR = $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
GEN_DIR = build/generated

ALL_PROTO := $(shell find . -not \( -path ./build -prune \) -name '*.proto')

# PHP renderings require the first character of the package prefix to be capitalized.
# Ex: caseylucas => Caseylucas
CAPITAL_PACKAGE_PREFIX = $(shell echo $(PACKAGE_PREFIX) | head -c 1 | tr '[a-z]' '[A-Z]')$(shell echo $(PACKAGE_PREFIX) | cut -c 2-)

.PHONY: help
help:
	@echo "Make targets:"
	@echo "- generate: Runs prototool in order to validate / lint all *.proto files"
	@echo "- repos:    Create required protobuf-* github repos"
	@echo "- diff:     Show diff of *generated* code. Does not commit changes - just shows diff"
	@echo "- commit:   Commits (and pushes) generated code (NOT *.proto files)"
	@echo "- clean:    Cleans up intermediate files"
	@echo "- help:     Print this help"
	@echo ""
	@echo "When adding a *new* folder, you'll need to edit rendered_repos.mk and add to the REPOS variable. Be sure to add"
	@echo "a protobuf-X-L for every X service with desired language L."
	@echo ""
	@echo "Typically you can use 'make generate' while you are working issues out.  Then run 'make diff' to view the"
	@echo "rendered code changes. Finally run 'make commit' to commit/push rendered code changes."


.PHONY: generate
generate: build/last_generated_touchfile ;

build/last_generated_touchfile: $(ALL_PROTO)
	@rm -rf build/generated
	@# If prototool/protoc is generating output which you don't understand, add '--debug' to
	@# prototool command to see lots of debug info.
	docker run -v "$(MAKEFILE_DIR):/work" uber/prototool:$(DOCKER_PROTOTOOL_VERSION) prototool all
	@touch build/last_generated_touchfile

# Run prepare-repo.sh helper script to prepare a git repo.
.PHONY: repo-%
repo-%:
	@mkdir -p $(REPO_DIR)
	@echo preparing repo $*
	@cd $(REPO_DIR) && $(MAKEFILE_DIR)prepare-repo.sh $* $(PACKAGE_PREFIX)

# Create all repositories.
.PHONY: repos
repos: $(foreach x,$(REPOS),repo-$x) ;

.PHONY: copy-generated
copy-generated: $(foreach x,$(REPOS),repo-$x copy-generated-$x) ;

# Copy generated go files. Add required dependencies to go.mod if they're
# not already there.
.PHONY: copy-generated-protobuf-%-go
copy-generated-protobuf-%-go: DEST_REPO_DIR = $(REPO_DIR)/protobuf-$*-go/
copy-generated-protobuf-%-go: generate repo-protobuf-%-go
	@rm -rf $(DEST_REPO_DIR)$*
	@cp -a $(GEN_DIR)/go/$(PACKAGE_PREFIX)/$* $(DEST_REPO_DIR)
	@set -e ;\
	cd $(DEST_REPO_DIR) ;\
	for x in $(GO_MOD_REQUIREMENTS); \
	do \
		y=$$(echo $$x | sed -e 's/@/ /'); \
		if ! grep -q "$$y" go.mod; \
		then \
			go get $$x; \
		fi; \
	done ;\
	git add .

# Copy generated typescript files.
# If there inter-service dependencies that should also be packaged
# up into a repo, include the other rendered files by setting a variable like
# OTHER_TS_DEPS_packaged =  other_repsitory
# Ex: This will cause service1 rendered files to be included in the service2 repository:
# OTHER_TS_DEPS_service2 = service1
.PHONY: copy-generated-protobuf-%-ts
copy-generated-protobuf-%-ts: DEST_REPO_DIR = $(REPO_DIR)/protobuf-$*-ts/
copy-generated-protobuf-%-ts: generate repo-protobuf-%-ts
	@rm -rf $(DEST_REPO_DIR)*.[jt]s $(DEST_REPO_DIR)$* $(DEST_REPO_DIR)$(PACKAGE_PREFIX)
	@mkdir -p $(DEST_REPO_DIR)$(PACKAGE_PREFIX)/$*
	@cp -a $(GEN_DIR)/ts/$(PACKAGE_PREFIX)/$* $(foreach x,$(OTHER_TS_DEPS_$*), $(GEN_DIR)/ts/$(PACKAGE_PREFIX)/$(x)) $(DEST_REPO_DIR)$(PACKAGE_PREFIX)
	@cd $(DEST_REPO_DIR) && git add .

# Copy generated PHP files.
.PHONY: copy-generated-protobuf-%-php
copy-generated-protobuf-%-php: DEST_REPO_DIR = $(REPO_DIR)/protobuf-$*-php/
copy-generated-protobuf-%-php: generate repo-protobuf-%-php ;
	@rm -rf $(DEST_REPO_DIR)GPBMetadata
	@mkdir -p $(DEST_REPO_DIR)GPBMetadata/$(CAPITAL_PACKAGE_PREFIX)
	@rm -rf $(DEST_REPO_DIR)$(CAPITAL_PACKAGE_PREFIX)
	@mkdir -p $(DEST_REPO_DIR)$(CAPITAL_PACKAGE_PREFIX)
	@cp -a $(GEN_DIR)/php/GPBMetadata/$(CAPITAL_PACKAGE_PREFIX)/$(shell echo $* | perl -pe 's/_(.)/\u\1/g; s/^(.)/\u\1/g') $(DEST_REPO_DIR)GPBMetadata/$(CAPITAL_PACKAGE_PREFIX)/
	@cp -a $(GEN_DIR)/php/$(CAPITAL_PACKAGE_PREFIX)/$(shell echo $* | perl -pe 's/_//g; s/^(.)/\u\1/g') $(DEST_REPO_DIR)$(CAPITAL_PACKAGE_PREFIX)/
	@cd $(DEST_REPO_DIR) && git add .

# Show differences for rendered files.
.PHONY: diff
diff: copy-generated
	@for d in $(REPO_DIRS); do echo checking $$d for changes; cd $(abspath $(MAKEFILE_DIR))/$$d && git diff --cached; done

# Commit and push generated files to remote repo.
.PHONY: commit
commit: copy-generated
	@for d in $(REPO_DIRS); do echo $$d; cd $(abspath $(MAKEFILE_DIR))/$$d && \
		if [ -n "$$(git status -s .)" ]; then \
			git add . && \
			git commit -m "protoc generated files" && \
			git push origin ; \
		fi; \
		done
	@if [ -n "$$(git status -s .)" ]; then \
		echo "***********************************************************************************"; \
		echo "***********************************************************************************"; \
		echo "There are outstanding changes in current directory. Be sure to commit them as well."; \
		echo "***********************************************************************************"; \
		echo "***********************************************************************************"; \
	fi

.PHONY: clean
clean:
	rm -rf build
