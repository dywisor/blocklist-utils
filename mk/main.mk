S_BIN      := $(S)/bin
S_SRC      := $(S)/src
S_SRC_C    := $(S_SRC)/C

DESTDIR     =
PREFIX      = /usr/local
EXEC_PREFIX = $(PREFIX)
BINDIR      = $(EXEC_PREFIX:/=)/bin

EXEMODE ?= 0755
INSMODE ?= 0644
DIRMODE ?= 0755

INSTALL ?= install

RM      ?= rm
RMF      = $(RM) -f

DODIR    = $(INSTALL) -d -m $(DIRMODE)
DOEXE    = $(INSTALL) -D -m $(EXEMODE)
DOINS    = $(INSTALL) -D -m $(INSMODE)

X_PERLCRITIC = perlcritic
PERLCRITIC_OPTS  =
PERLCRITIC_OPTS += --harsh
PERLCRITIC_OPTS += --verbose 11
PERLCRITIC_OPTS += --exclude CodeLayout::RequireTidyCode
PERLCRITIC_OPTS += --exclude Modules::ProhibitMultiplePackages
PERLCRITIC_OPTS += --exclude Subroutines::RequireArgUnpacking
PERLCRITIC_OPTS += --exclude ValuesAndExpressions::ProhibitNoisyQuotes
PERLCRITIC_OPTS += --exclude RegularExpressions::RequireDotMatchAnything
PERLCRITIC_OPTS += --exclude ControlStructures::ProhibitPostfixControls
PERLCRITIC_OPTS += --exclude Variables::ProhibitPunctuationVars
PERLCRITIC_OPTS += --exclude RegularExpressions::ProhibitComplexRegexes
PERLCRITIC_OPTS += --exclude ErrorHandling::RequireCarping
PERLCRITIC_OPTS += --exclude Subroutines::ProhibitExcessComplexity

all: progs

# addprefix <> patsubst ^%

progs: $(S_BIN)/ipset-gen $(S_BIN)/unbound-redirect-gen $(S_BIN)/squid-acl-gen

C_COMMON_DEP = $(S_SRC_C)/main.c $(S_SRC_C)/main.h
LAZY_COMPILE_C_PROG = $(CC) -static -std=c99 -D_POSIX_C_SOURCE=200809L -O2 -pipe -Wall -Wextra -pedantic

$(S_BIN)/ipset-gen: $(S_SRC_C)/ipset-gen.c $(C_COMMON_DEP)
	$(LAZY_COMPILE_C_PROG) -o $(@) $(S_SRC_C)/ipset-gen.c

$(S_BIN)/unbound-redirect-gen: $(S_SRC_C)/unbound-redirect-gen.c $(C_COMMON_DEP)
	$(LAZY_COMPILE_C_PROG) -o $(@) $(S_SRC_C)/unbound-redirect-gen.c

$(S_BIN)/squid-acl-gen: $(S_SRC_C)/squid-acl-gen.c $(C_COMMON_DEP)
	$(LAZY_COMPILE_C_PROG) -o $(@) $(S_SRC_C)/squid-acl-gen.c

install:
	false

uninstall:
	false

check:
	find $(S)/src -type f \( -name '*.pl' -or -name '*.pm' \) | \
		xargs -r -t -n 1 $(X_PERLCRITIC) $(PERLCRITIC_OPTS)


.PHONY: all progs install uninstall check
