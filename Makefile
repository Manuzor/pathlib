
ifeq ($(OUTDIR),)
  OUTDIR = output
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
