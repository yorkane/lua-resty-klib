INST_PREFIX ?= /usr
# INST_LIBDIR ?= $(INST_PREFIX)/lib/lua/5.1
# INST_LUADIR ?= $(INST_PREFIX)/share/lua/5.1
INST_LUADIR ?= $(INST_PREFIX)/local/openresty/site/lualib
INSTALL ?= install


.PHONY: default
default: test

### test:         Run test suite. Use test=... for specific tests
.PHONY: test
test:
	TEST_NGINX_LOG_LEVEL=info \
	prove

### install:      Install the library to runtime
.PHONY: install
install:
	mkdir -p $(INST_LUADIR)/klib/
	cp -f lib/klib/*.lua $(INST_LUADIR)/klib/

### lint:         Lint Lua source code
.PHONY: lint
lint:
	luacheck -q lib


### help:         Show Makefile rules
.PHONY: help
help:
	@echo Makefile rules:
	@echo
	@grep -E '^### [-A-Za-z0-9_]+:' Makefile | sed 's/###/   /'
