all::

# Define NO_VISIBILITY if your compiler does not support symbol
# visibility in general (and the -fvisibility switch in particular).

DOXYGEN = doxygen
RANLIB  = ranlib

prefix=/usr/local

uname_S := $(shell sh -c 'uname -s 2>/dev/null || echo no')

CFLAGS = -g -O2 -Wall
OS     = unix

# Platform specific tweaks

ifneq (,$(findstring CYGWIN,$(uname_S)))
	NO_VISIBILITY=YesPlease
endif

BASIC_CFLAGS := -Isrc
ifndef NO_VISIBILITY
BASIC_CFLAGS += -fvisibility=hidden
endif
ALL_CFLAGS = $(CFLAGS) $(BASIC_CFLAGS)

SRC_C = $(wildcard src/*.c)
OBJS = $(patsubst %.c,%.o,$(SRC_C))
HDRS = $(wildcard src/*.h)
PUBLIC_HEADERS = $(wildcard src/git/*.h)
HDRS += $(PUBLIC_HEADERS)

GIT_LIB = libgit2.a

TEST_OBJ = $(patsubst %.c,%.o,\
           $(wildcard tests/t[0-9][0-9][0-9][0-9]-*.c))
TEST_EXE = $(patsubst %.o,%.exe,$(TEST_OBJ))
TEST_RUN = $(patsubst %.exe,%.run,$(TEST_EXE))

all:: $(GIT_LIB)

clean:
	rm -f $(GIT_LIB)
	rm -f src/*.o
	rm -f tests/*.o tests/*.exe tests/*.toc
	rm -rf trash-*.exe
	rm -rf apidocs

apidocs:
	$(DOXYGEN) api.doxygen
	cp CONVENTIONS apidocs/

test: $(TEST_RUN)

sparse:
	cgcc -no-compile $(ALL_CFLAGS) $(SPARSE_FLAGS) $(SRC_C)

install-headers: $(PUBLIC_HEADERS)
	@mkdir -p /tmp/gitinc/git
	@for i in $^; do cat .HEADER $$i > /tmp/gitinc/$${i##src/}; done

install: $(GIT_LIB) $(PUBLIC_HEADERS) libgit2.pc
	@mkdir -p $(DESTDIR)/$(prefix)/include/git
	@for i in $(PUBLIC_HEADERS); do \
		cat .HEADER $$i > $(DESTDIR)/$(prefix)/include/$${i##src/}; \
	done
	@mkdir -p $(DESTDIR)/$(prefix)/lib
	@cp -f $(GIT_LIB) $(DESTDIR)/$(prefix)/lib/libgit2.a
	@mkdir -p $(DESTDIR)/$(prefix)/lib/pkgconfig
	@cp -f libgit2.pc $(DESTDIR)/$(prefix)/lib/pkgconfig/libgit2.pc

uninstall:
	@rm -f $(DESTDIR)/$(prefix)/lib/libgit2.a
	@rm -f $(DESTDIR)/$(prefix)/lib/pkgconfig/libgit2.pc
	@for i in $(PUBLIC_HEADERS); do \
		rm -f $(DESTDIR)/$(prefix)/include/$${i##src/}; \
	done
	@rmdir $(DESTDIR)/$(prefix)/include/git

.c.o:
	$(CC) $(ALL_CFLAGS) -c $< -o $@

$(OBJS): $(HDRS)
$(GIT_LIB): $(OBJS)
	rm -f $(LIB)
	$(AR) cr $(GIT_LIB) $(OBJS)
	$(RANLIB) $(GIT_LIB)

T_HDR         = tests/test_lib.h
T_LIB         = tests/test_lib.o
T_MAIN_C      = tests/test_main.c

$(T_LIB):    $(T_HDR) $(HDRS)
$(TEST_OBJ): $(T_HDR) $(HDRS)

$(patsubst %.exe,%.toc,$(TEST_EXE)): tests/%.toc: tests/%.c
	grep BEGIN_TEST $< >$@+
	mv $@+ $@

$(TEST_OBJ): tests/%.o: tests/%.c
	$(CC) $(ALL_CFLAGS) -c $< -o $@

$(patsubst %.exe,%_main.o,$(TEST_EXE)): tests/%_main.o: $(HDRS)
$(patsubst %.exe,%_main.o,$(TEST_EXE)): tests/%_main.o: $(T_MAIN_C)
$(patsubst %.exe,%_main.o,$(TEST_EXE)): tests/%_main.o: tests/%.toc
	$(CC) -Isrc -I. '-DTEST_TOC="$<"' \
		-c $(T_MAIN_C) \
		-o $@

$(TEST_EXE): tests/%.exe: $(T_LIB) $(GIT_LIB)
$(TEST_EXE): tests/%.exe: tests/%.o tests/%_main.o
	$(CC) -o $@ \
		$(patsubst %.exe,%_main.o,$@) \
		$(patsubst %.exe,%.o,$@) \
		$(T_LIB) -L. -lgit2 -lz -lcrypto

$(TEST_RUN): tests/%.run: tests/%.exe
	@t=trash-$(<F) && \
	 mkdir $$t && \
	 if (cd $$t && ../$<); \
	  then rm -rf $$t; \
	  else rmdir $$t; exit 1; \
	 fi

libgit2.pc: libgit2.pc.in
	sed 's#@prefix@#$(prefix)#' $< > $@

.PHONY: all
.PHONY: clean
.PHONY: test $(TEST_RUN)
.PHONY: apidocs
.PHONY: install-headers
.PHONY: install uninstall
.PHONY: sparse
