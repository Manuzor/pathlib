
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
	rm -rf $(OUTDIR)

runtests: tests
	$(OUTDIR)/pathlibtests.exe
	

lib: $(OUTDIR)/pathlib.lib
$(OUTDIR)/pathlib.lib: $(PATHLIB_DFILES)
	$(eval DFLAGS = $(DFLAGSCOMMON))
	$(eval DFLAGS += -lib)
	$(eval DFLAGS += -od$(OUTDIR))
	dmd $(PATHLIB_DFILES) $(DFLAGS)

tests: $(OUTDIR)/pathlibtests.exe
$(OUTDIR)/pathlibtests.exe: $(PATHLIB_DFILES)
	$(eval DFLAGS = $(DFLAGSCOMMON))
	$(eval DFLAGS += -unittest)
	$(eval DFLAGS += -main)
	$(eval DFLAGS += -od$(OUTDIR))
	dmd $(PATHLIB_DFILES) $(DFLAGS) -of$(OUTDIR)/pathlibtests.exe
