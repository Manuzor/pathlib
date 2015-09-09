CURRENT_MAKEFILE = $(abspath $(lastword $(MAKEFILE_LIST)))
ifneq ($(shell uname -s | grep -i cygwin),)
  # We are in a cygwin shell.
  ROOT = $(shell cygpath -m $(dir $(CURRENT_MAKEFILE)))
else
  # We are in some other shell.
  ROOT = $(dir $(CURRENT_MAKEFILE))
endif

ifeq ($(ROOT),)
  error "Unable to determine current working dir."
endif

ifeq ($(OUTDIR),)
  OUTDIR = $(ROOT)/output
endif

ifeq ($(DFLAGSCOMMON),)
  DFLAGSCOMMON += -m64
  DFLAGSCOMMON += -gc
  DFLAGSCOMMON += -L/INCREMENTAL:NO
  DFLAGSCOMMON += -w
endif

  

DFILES = $(wildcard code/*.d)


default: all

all: lib tests

.PHONY: clean
clean:
	@echo "Cleaning all '$(OUTDIR)/*pathlib*' files ..."
	@find $(OUTDIR)/ -type f | grep pathlib | xargs rm -f

lib: $(DFILES)
	$(eval DFLAGS = $(DFLAGSCOMMON))
	$(eval DFLAGS += -lib)
	$(eval DFLAGS += -od$(OUTDIR))
	dmd $(DFILES) $(DFLAGS)

tests: $(DFILES)
	$(eval DFLAGS = $(DFLAGSCOMMON))
	$(eval DFLAGS += -unittest)
	$(eval DFLAGS += -main)
	$(eval DFLAGS += -od$(OUTDIR))
	dmd $(DFILES) $(DFLAGS) -of$(OUTDIR)/pathlibtests.exe

runtests: tests
	$(OUTDIR)/pathlibtests.exe
