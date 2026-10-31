ADDON   := Trovekeeper

REQUIRED  := clean distclean debug install uninstall deploy lint
HELP_VARS := WOW_RETAIL_ADDON_FOLDER WOW_DIR FLAVOR CONFIRM TAG DRY_RUN

## WOW_RETAIL_ADDON_FOLDER: Interface/AddOns to install into
WOW_RETAIL_ADDON_FOLDER ?=

## WOW_DIR: World of Warcraft folder, overrides the auto-detection
WOW_DIR ?=

## FLAVOR: client folder below WOW_DIR
FLAVOR ?= _retail_

## CONFIRM: yes = make purge deletes the SavedVariables
CONFIRM ?=

TOC     := $(ADDON)_Mainline.toc
VERSION := $(shell sed -n 's/^## Version: //p' $(TOC))

INSTALL_FILES := $(TOC) embeds.xml CHANGELOG.md LICENSE
INSTALL_DIRS  := Core UI Locales Skin Media
LIB_DIRS      := LibStub CallbackHandler-1.0 LibDataBroker-1.1 LibDBIcon-1.0 HereBeDragons

LUA_DIRS := Core UI Locales Skin
DIST_DIR := dist
ZIP      := $(DIST_DIR)/$(ADDON)-$(VERSION).zip

# scratch venv for the Lua syntax check, so `make lint` needs nothing installed
VENV     := .build/luaenv
PY       := $(VENV)/bin/python

LINT_TOOLS := tools/luacheck.py tools/xmlcheck.py tools/toccheck.py tools/localecheck.py

GITHUB_URL := git@github.com:lasse-tech/trovekeeper.git

## TAG: release tag make github exports
TAG ?= v$(VERSION)

## DRY_RUN: 1 = make github commits in dist/github, pushes nothing
DRY_RUN ?= 0

# public export: one commit per release tag
PUBLIC_DIR   := $(DIST_DIR)/public
PUBLIC_PATHS := $(INSTALL_FILES) $(INSTALL_DIRS) Libs README.md .pkgmeta github Makefile Makefile.bat \
	scripts $(LINT_TOOLS) .gitignore
PUBLIC_NAME  := Lars Gossard
PUBLIC_EMAIL := lars@lasse-tech.de

WOW_CANDIDATES := \
	"/games/battlenet/drive_c/Program Files (x86)/World of Warcraft" \
	"$$HOME/Games/World of Warcraft" \
	"/games/World of Warcraft" \
	"C:/Program Files (x86)/World of Warcraft"

FIND_WOW = if [ -n "$(WOW_DIR)" ]; then echo "$(WOW_DIR)"; else for d in $(WOW_CANDIDATES); do if [ -d "$$d/$(FLAVOR)" ]; then echo "$$d"; break; fi; done; fi
FIND_ADDONS = if [ -n "$(WOW_RETAIL_ADDON_FOLDER)" ]; then echo "$(WOW_RETAIL_ADDON_FOLDER)"; else wow=$$($(FIND_WOW)); if [ -n "$$wow" ]; then echo "$$wow/$(FLAVOR)/Interface/AddOns"; fi; fi

NO_ADDONS_MSG = echo "AddOns folder not found. Set WOW_RETAIL_ADDON_FOLDER=/path/to/Interface/AddOns, or pass WOW_DIR=/path/to/World of Warcraft"

.DEFAULT_GOAL := help
.PHONY: help version icon lint check check-toc check-xml check-locales ruff install debug uninstall purge \
	dist deploy release public github clean distclean

##@ General

## help: list targets and variables
help:
	@echo "$(ADDON) $(VERSION)"
	@$(foreach v,$(HELP_VARS),$(v)='$($(v))') awk -f scripts/make-help.awk $(firstword $(MAKEFILE_LIST))

## version: print the addon version
version:
	@echo "$(VERSION)"

## icon: rebuild Media/Icon.png and brand/*.png from the SVGs
icon: $(PY)
	@$(VENV)/bin/pip install --quiet pillow
	@command -v rsvg-convert >/dev/null 2>&1 || $(VENV)/bin/pip install --quiet cairosvg
	@$(PY) tools/build-icon.py brand Media

$(PY):
	@mkdir -p .build
	@python3 -m venv $(VENV)
	@$(VENV)/bin/pip install --quiet lupa

##@ Checks

## check: load every Lua file with a real Lua loader
check: $(PY)
	@$(PY) tools/luacheck.py $$(find $(LUA_DIRS) -name '*.lua' | sort)

## check-xml: parse every XML file outside Libs/
check-xml:
	@python3 tools/xmlcheck.py $$(find . -name '*.xml' -not -path './Libs/*' -not -path './$(DIST_DIR)/*' | sort)

## check-toc: TOC file list and file tree match in both directions
check-toc:
	@python3 tools/toccheck.py $(TOC) $(LUA_DIRS)

## check-locales: every locale key defined and translated
check-locales:
	@python3 tools/localecheck.py Locales/enUS.lua Locales/deDE.lua -- $(LUA_DIRS)

# tools/build-icon.py stays out of the public export
PY_TOOLS := $(wildcard tools/*.py)

## ruff: Python checks on tools/, any finding fails
ruff:
	@command -v ruff >/dev/null 2>&1 || { echo "ruff not found"; exit 1; }
	@ruff check --no-cache -q $(PY_TOOLS) && echo "ruff: no findings"

## lint: Lua, XML, TOC, locales, ruff, Makefile comments (BLOCKER)
lint: check check-xml check-toc check-locales ruff
	@awk -v required="$(REQUIRED)" -f scripts/make-lint.awk $(firstword $(MAKEFILE_LIST))
	@awk -v required="$(REQUIRED)" -v bat=1 -f scripts/make-lint.awk Makefile.bat
	@echo "make: comments ok"

##@ Client

## install: copy the addon into the live WoW client
install:
	@set -e; \
	dir=$$($(FIND_ADDONS)); \
	if [ -z "$$dir" ]; then $(NO_ADDONS_MSG); exit 1; fi; \
	target="$$dir/$(ADDON)"; \
	mkdir -p "$$target"; \
	cp $(INSTALL_FILES) "$$target/"; \
	for d in $(INSTALL_DIRS); do rm -rf "$$target/$$d"; cp -r "$$d" "$$target/"; done; \
	mkdir -p "$$target/Libs"; \
	for l in $(LIB_DIRS); do rm -rf "$$target/Libs/$$l"; cp -r "Libs/$$l" "$$target/Libs/"; done; \
	echo "installed $(ADDON) $(VERSION) -> $$target"

# Config.wtf is backed up once before it is touched.
## debug: install and turn the client's Lua error display on
debug: install
	@wow=$$($(FIND_WOW)); \
	if [ -z "$$wow" ]; then echo "WoW folder not found, skipped the error-display setting"; exit 0; fi; \
	cfg="$$wow/$(FLAVOR)/WTF/Config.wtf"; \
	if [ ! -f "$$cfg" ]; then echo "no Config.wtf yet, skipped the error-display setting"; exit 0; fi; \
	[ -f "$$cfg.trovekeeper.bak" ] || cp "$$cfg" "$$cfg.trovekeeper.bak"; \
	if grep -q '^SET scriptErrors' "$$cfg"; then \
		sed -i 's/^SET scriptErrors .*/SET scriptErrors "1"/' "$$cfg"; \
	else \
		echo 'SET scriptErrors "1"' >> "$$cfg"; \
	fi; \
	echo "debug: scriptErrors is on in $$cfg"

## uninstall: remove the addon, SavedVariables stay
uninstall:
	@set -e; \
	dir=$$($(FIND_ADDONS)); \
	if [ -z "$$dir" ]; then $(NO_ADDONS_MSG); exit 1; fi; \
	rm -rf "$$dir/$(ADDON)"; \
	echo "removed $$dir/$(ADDON) (SavedVariables kept)"

## purge: uninstall and delete the SavedVariables (needs CONFIRM=yes)
purge: uninstall
	@if [ "$(CONFIRM)" != "yes" ]; then echo "refusing to delete SavedVariables without CONFIRM=yes"; exit 1; fi; \
	wow=$$($(FIND_WOW)); \
	if [ -z "$$wow" ]; then $(NO_ADDONS_MSG); exit 1; fi; \
	find "$$wow/$(FLAVOR)/WTF" -name '$(ADDON).lua*' -print -delete 2>/dev/null; \
	echo "SavedVariables deleted"

##@ Release

## dist: build dist/Trovekeeper-<version>.zip
dist: lint
	@rm -rf $(DIST_DIR)/$(ADDON)
	@mkdir -p $(DIST_DIR)/$(ADDON)/Libs
	@cp $(INSTALL_FILES) $(DIST_DIR)/$(ADDON)/
	@for d in $(INSTALL_DIRS); do cp -r "$$d" $(DIST_DIR)/$(ADDON)/; done
	@for l in $(LIB_DIRS); do cp -r "Libs/$$l" $(DIST_DIR)/$(ADDON)/Libs/; done
	@rm -f $(ZIP)
	@cd $(DIST_DIR) && zip -qr "$(ADDON)-$(VERSION).zip" $(ADDON)
	@echo "built $(ZIP)"

## deploy: none - installation: README.md, section Installation
deploy:
	@echo "No deploy: see README.md, section Installation"

## release: print the commands that tag v<version> and push it to Forgejo (exported to GitHub)
release:
	@echo "git tag v$(VERSION) && git push origin main v$(VERSION)"

# github/gitattributes: renamed on export (git archive would apply it to github/)
# $(call public-tree,<ref>,<out dir>)
define public-tree
	rm -rf "$(2)" && mkdir -p "$(2)"
	git archive "$(1)" $(PUBLIC_PATHS) | tar -x -C "$(2)"
	cp -r "$(2)/github/." "$(2)/" && rm -r "$(2)/github"
	mv "$(2)/gitattributes" "$(2)/.gitattributes"
endef

## public: build the public export of HEAD into dist/public
public:
	$(call public-tree,HEAD,$(PUBLIC_DIR))
	@cd $(PUBLIC_DIR) && find . -type f | sort

## github: export TAG to GitHub as one commit and tag it
github:
	@git rev-parse -q --verify "refs/tags/$(TAG)" >/dev/null || { echo "tag $(TAG) not found"; exit 1; }
	@! git ls-remote --exit-code --tags $(GITHUB_URL) "refs/tags/$(TAG)" >/dev/null || { echo "$(TAG) is on GitHub already"; exit 1; }
	$(call public-tree,$(TAG),$(PUBLIC_DIR))
	rm -rf $(DIST_DIR)/github && git clone -q $(GITHUB_URL) $(DIST_DIR)/github
	@cd $(DIST_DIR)/github && git checkout -q -B main \
		&& find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + \
		&& cp -r ../public/. . && git add -A \
		&& GIT_AUTHOR_NAME="$(PUBLIC_NAME)" GIT_AUTHOR_EMAIL="$(PUBLIC_EMAIL)" \
		GIT_COMMITTER_NAME="$(PUBLIC_NAME)" GIT_COMMITTER_EMAIL="$(PUBLIC_EMAIL)" \
		git commit -qm "$(ADDON) $(TAG:v%=%)" && git tag "$(TAG)" \
		&& git show --format="%h %s" --stat=100 HEAD | sed '$$d'
	@if [ "$(DRY_RUN)" = "1" ]; then echo "DRY_RUN=1: nothing pushed, see $(DIST_DIR)/github"; \
	else cd $(DIST_DIR)/github && git push -q origin main "refs/tags/$(TAG)" && echo "pushed $(TAG) to GitHub"; fi

## clean: remove build output
clean:
	@rm -rf $(DIST_DIR)
	@echo "cleaned"

## distclean: clean, plus the lint venv
distclean: clean
	@rm -rf .build
	@echo "distcleaned"
