#

# Change this to match your libevent installation.
EVENT_LIB=-levent
EVENT_LIBDIR=/usr/local/lib
EVENT_INCDIR=/usr/local/include

NAME=liboevent
OBJECTS=libevent.cmo
XOBJECTS=$(OBJECTS:.cmo=.cmx)
C_OBJECTS=event_stubs.o

ARCHIVE=$(NAME).cma
XARCHIVE=$(ARCHIVE:.cma=.cmxa)
CARCHIVE_NAME=mloevent
CARCHIVE=lib$(CARCHIVE_NAME).a

# Flags for the C compiler.
CFLAGS=-DFULL_UNROLL -Wall -O2 -I$(EVENT_INCDIR)

OCAMLC=ocamlc
OCAMLOPT=ocamlopt
OCAMLDEP=ocamldep
OCAMLMKLIB=ocamlmklib
OCAMLDOC=ocamldoc
OCAMLFIND=ocamlfind

.PHONY: build
build: all allopt

.PHONY: all
all: $(ARCHIVE)
.PHONY: allopt
allopt:  $(XARCHIVE)

depend: *.c *.ml *.mli
	gcc -MM *.c > depend
	$(OCAMLDEP) *.mli *.ml >> depend

## Library creation
$(CARCHIVE): $(C_OBJECTS)
	$(OCAMLMKLIB) -oc $(CARCHIVE_NAME) $(C_OBJECTS) \
	-L$(EVENT_LIBDIR) $(EVENT_LIB)
$(ARCHIVE): $(CARCHIVE) $(OBJECTS)
	$(OCAMLMKLIB) -o $(NAME) $(OBJECTS) -oc $(CARCHIVE_NAME) \
	-L$(EVENT_LIBDIR) $(EVENT_LIB)
$(XARCHIVE): $(CARCHIVE) $(XOBJECTS)
	$(OCAMLMKLIB) -o $(NAME) $(XOBJECTS) -oc $(CARCHIVE_NAME) \
	-L$(EVENT_LIBDIR) $(EVENT_LIB)

## Installation
.PHONY: install
install:
	{ test ! -f $(XARCHIVE) || extra="$(XARCHIVE) $(OBJECTS:.cmo=.cmx) $(NAME).a"; }; \
	$(OCAMLFIND) install event META $(OBJECTS:.cmo=.cmi) $(OBJECTS:.cmo=.mli) $(ARCHIVE) \
	dll$(CARCHIVE_NAME).so lib$(CARCHIVE_NAME).a $$extra

.PHONY: uninstall
uninstall:
	$(OCAMLFIND) remove event

## Documentation
.PHONY: doc
doc: FORCE
	cd doc; $(OCAMLDOC) -html -I .. ../*.mli

## Testing
.PHONY: test
test: testbyte testopt
.PHONY: testbyte
testbyte: unittest
	./unittest
.PHONY: testopt
testopt: unittest.opt
	./unittest.opt
unittest: all unittest.ml
	$(OCAMLFIND) ocamlc -dllpath . -o unittest -package oUnit -cclib -L. -linkpkg \
	$(ARCHIVE) unittest.ml
unittest.opt: allopt unittest.ml
	$(OCAMLFIND) ocamlopt -o unittest.opt -package oUnit -cclib -L. -linkpkg \
	$(XARCHIVE) unittest.ml

## Cleaning up
.PHONY: clean
clean::
	rm -f *~ *.cm* *.o *.a *.so doc/*.html doc/*.css depend \
	unittest unittest.opt

FORCE:

.SUFFIXES: .ml .mli .cmo .cmi .cmx

.mli.cmi:
	$(OCAMLC) -c $(COMPFLAGS) $<
.ml.cmo:
	$(OCAMLC) -c $(COMPLAGS) -nolabels $<
.ml.cmx:
	$(OCAMLOPT) -c $(COMPFLAGS) -nolabels $<
.c.o:
	$(OCAMLC) -c -ccopt "$(CFLAGS)" $<

include depend
