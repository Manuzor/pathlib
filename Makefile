
OUTDIR = output

DFLAGS += -m64
DFLAGS += -gc
DFLAGS += -w
DFLAGS += -debug
DFLAGS += -gs
  
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
	$(eval LIB_DFLAGS = $(DFLAGS))
	$(eval LIB_DFLAGS += -lib)
	dmd $(PATHLIB_DFILES) $(LIB_DFLAGS) -of$(OUTDIR)/pathlib.lib

tests: $(OUTDIR)/pathlibtests.exe
$(OUTDIR)/pathlibtests.exe: $(PATHLIB_DFILES)
	$(eval TESTS_DFLAGS = $(DFLAGS))
	$(eval TESTS_DFLAGS += -unittest)
	$(eval TESTS_DFLAGS += -main)
	$(eval TESTS_DFLAGS += -od$(OUTDIR))
	dmd $(PATHLIB_DFILES) $(TESTS_DFLAGS) -of$(OUTDIR)/pathlibtests.exe
