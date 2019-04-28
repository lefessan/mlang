# Copyright Inria, contributor: Denis Merigoux <denis.merigoux@inria.fr> (2018)
#
# This software is a computer program whose purpose is to compile and analyze
# programs written in the M langage, created by thge DGFiP.
#
# This software is governed by the CeCILL-C license under French law and
# abiding by the rules of distribution of free software.  You can  use,
# modify and/ or redistribute the software under the terms of the CeCILL-C
# license as circulated by CEA, CNRS and INRIA at the following URL
# http://www.cecill.info.
#
# As a counterpart to the access to the source code and  rights to copy,
# modify and redistribute granted by the license, users are provided only
# with a limited warranty  and the software's author,  the holder of the
# economic rights,  and the successive licensors  have only  limited
# liability.
#
# In this respect, the user's attention is drawn to the risks associated
# with loading,  using,  modifying and/or developing or reproducing the
# software by the user in light of its specific status of free software,
# that may mean  that it is complicated to manipulate,  and  that  also
# therefore means  that it is reserved for developers  and  experienced
# professionals having in-depth computer knowledge. Users are therefore
# encouraged to load and test the software's suitability as regards their
# requirements in conditions enabling the security of their systems and/or
# data to be ensured and,  more generally, to use and operate it in the
# same conditions as regards security.
#
# The fact that you are presently reading this means that you have had
# knowledge of the CeCILL-C license and that you accept its terms.

SOURCE_DIR=calculette-impots-m-source-code/sources-latin1/sourcesm2015m_4_6
OCAMLDOC_FILES = src/**/*.ml src/*.ml
DOC_FOLDER = doc
ANSI_FOLDER = $(shell ocamlfind query ANSITerminal)
GRAPH_FOLDER = $(shell ocamlfind query ocamlgraph)
Z3_FOLDER = $(shell ocamlfind query z3)
OCAML_INCLUDES = \
	-I _build/src \
	-I _build/src/parsing \
	-I _build/src/cfg \
	-I _build/src/analysis \
	-I _build/src/optimization \
	-I _build/src/z3 \
	-I $(ANSI_FOLDER) \
	-I $(GRAPH_FOLDER) \
	-I $(Z3_FOLDER)


deps:
	opam install ppx_deriving ANSITerminal str ocamlgraph z3

build:
	ocamlbuild -cflag -g -use-ocamlfind src/main.native

test: build
	  export LD_LIBRARY_PATH=$(Z3_FOLDER)
		./main.native --debug test.m

parse_all: build
		./main.native $(wildcard $(SOURCE_DIR)/*.m) --debug

doc:
	mkdir -p $(DOC_FOLDER)
	opam config env
	ocamldoc \
		$(OCAML_INCLUDES) \
		-html -keep-code -m p -sort \
		-colorize-code -d $(DOC_FOLDER) \
		-t "Verifisc M compiler" \
		$(OCAMLDOC_FILES)

.PHONY: build doc
