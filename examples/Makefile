#
# Simple makefile to build the example programs. The libevent library
# must be installed first.
#

all: fifo_example signal_example http_server

fifo_example: fifo_example.ml
	ocamlfind ocamlc -o fifo_example -package libevent -linkpkg \
	fifo_example.ml

signal_example: signal_example.ml
	ocamlfind ocamlc -o signal_example -package libevent -linkpkg \
	signal_example.ml

http_server: http_server.ml
	ocamlfind ocamlc -o http_server -package libevent -linkpkg \
	http_server.ml

.PHONY: clean
clean::
	rm -f *~ *.cm* *.o fifo_example signal_example http_server

