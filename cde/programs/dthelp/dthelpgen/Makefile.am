MAINTAINERCLEANFILES = Makefile.in

bin_PROGRAMS = dthelpgen

bin_SCRIPTS = dthelpgen.dtsh

BUILT_SOURCES = dthelpgen.dtsh
CLEANFILES = dthelpgen.dtsh
EXTRA_DIST = dthelpgen.dtsh.in

dthelpgen.dtsh: $(srcdir)/dthelpgen.dtsh.in Makefile
	sed -e 's|@DTKSH_BINARY@|$(bindir)/dtksh|g' \
	    -e 's|@DTKSH_FUNCTIONS@|$(CDE_DTKSH_DATA_DIR)/DtFuncs.dtsh|g' \
	    $< > $@.tmp && chmod 755 $@.tmp && mv $@.tmp $@

dthelpgen_CPPFLAGS = -DCDE_INSTALLATION_TOP=\"$(CDE_INSTALLATION_TOP)\" \
-DCDE_DATA_TOP=\"$(CDE_DATA_TOP)\" \
		   -DCDE_CONFIGURATION_TOP=\"$(CDE_CONFIGURATION_TOP)\" \
		   -I ../../../lib/DtHelp

dthelpgen_LDADD = $(DTCLIENTLIBS) $(XTOOLLIB)

dthelpgen_SOURCES = helpgen.c
