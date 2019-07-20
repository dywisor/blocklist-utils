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
PERLCRITIC_OPTS += --brutal
PERLCRITIC_OPTS += --verbose 11
PERLCRITIC_OPTS += --exclude CodeLayout::RequireTidyCode
PERLCRITIC_OPTS += --exclude Modules::ProhibitMultiplePackages
PERLCRITIC_OPTS += --exclude Subroutines::RequireArgUnpacking
PERLCRITIC_OPTS += --exclude ValuesAndExpressions::ProhibitNoisyQuotes
PERLCRITIC_OPTS += --exclude RegularExpressions::RequireDotMatchAnything
PERLCRITIC_OPTS += --exclude ControlStructures::ProhibitPostfixControls
PERLCRITIC_OPTS += --exclude Variables::ProhibitPunctuationVars


all:

install:
	false

uninstall:
	false

check:
	find $(S)/src -type f \( -name '*.pl' -or -name '*.pm' \) | \
		xargs -r -t -n 1 $(X_PERLCRITIC) $(PERLCRITIC_OPTS)


.PHONY: all install uninstall check
