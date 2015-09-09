
OUTDIR = output

DFLAGSCOMMON += -m64
DFLAGSCOMMON += -gc
DFLAGSCOMMON += -w
  
PATHLIB_CODEDIR = $(CUR_MAKEFILEDIR)code
PATHLIB_DFILES = $(shell find code -name '*.d')


default: all

all: lib tests

.PHONY: clean
clean:
	@echo "Cleaning all '$(OUTDIR)/*pathlib*' files ..."
	@find $(OUTDIR)/ -type f | grep pathlib | xargs rm -f

lib: $(OUTDIR)/pathlib.lib
tests: $(OUTDIR)/pathlibtests.exe
runtests: tests
	$(OUTDIR)/pathlibtests.exe


$(OUTDIR)/pathlib.lib: $(PATHLIB_DFILES)
	$(eval DFLAGS = $(DFLAGSCOMMON))
	$(eval DFLAGS += -lib)
	$(eval DFLAGS += -od$(OUTDIR))
	dmd $(PATHLIB_DFILES) $(DFLAGS)

$(OUTDIR)/pathlibtests.exe: $(PATHLIB_DFILES)
	$(eval DFLAGS = $(DFLAGSCOMMON))
	$(eval DFLAGS += -unittest)
	$(eval DFLAGS += -main)
	$(eval DFLAGS += -od$(OUTDIR))
	dmd $(PATHLIB_DFILES) $(DFLAGS) -of$(OUTDIR)/pathlibtests.exe
