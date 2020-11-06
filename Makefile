##################################################
# Variables
##################################################

SOURCE_DIR_2015=$(PWD)/ir-calcul/sources2015m_4_6/*.m
SOURCE_DIR_2016=$(PWD)/ir-calcul/sources2016m_4_5/*.m
SOURCE_DIR_2017=$(PWD)/ir-calcul/sources2017m_6_10/*.m
SOURCE_DIR_2018=$(PWD)/ir-calcul/sources2018m_6_7/*.m

SOURCE_FILES?=$(SOURCE_DIR_2018)

ifeq ($(OPTIMIZE), 1)
    OPTIMIZE_FLAG=-O
else
    OPTIMIZE_FLAG=
endif

ifeq ($(CODE_COVERAGE), 1)
    CODE_COVERAGE_FLAG=--code_coverage
else
    CODE_COVERAGE_FLAG=
endif

MLANG_BIN=dune exec --no-print-director src/main.exe --

MPP_FILE?=$(PWD)/mpp_specs/2018_6_7.mpp

MPP_FUNCTION?=compute_double_liquidation_pvro

PRECISION?=double

TEST_ERROR_MARGIN?=0.

MLANG_DEFAULT_OPTS=\
	--display_time --debug \
	--precision $(PRECISION) \
	--mpp_file=$(MPP_FILE) \
	--test_error_margin=0. \
	--mpp_function=$(MPP_FUNCTION)

MLANG=$(MLANG_BIN) $(MLANG_DEFAULT_OPTS) $(OPTIMIZE_FLAG) $(CODE_COVERAGE_FLAG)

TESTS_DIR?=random_tests/

default: build

##################################################
# Building the compiler
##################################################

deps:
	opam install ppx_deriving ANSITerminal re ocamlgraph dune menhir \
		cmdliner dune-build-info visitors parmap num ocamlformat mlgmpidl \
		interval
	git submodule update --init --recursive

format:
	dune build @fmt --auto-promote | true

build: format
	dune build

##################################################
# Testing the compiler
##################################################

# use: TEST_FILE=bla make test
test: build
	$(MLANG) --run_test=$(TEST_FILE) $(SOURCE_FILES)

# use: TESTS_DIR=bla make test
tests: build
	$(MLANG) --run_all_tests=$(TESTS_DIR) $(SOURCE_FILES)

quick_test:
	$(MLANG) --backend interpreter --function_spec m_specs/complex_case_with_ins_outs_2018.m_spec $(SOURCE_FILES)

##################################################
# Doc and examples
##################################################

doc: FORCE
	dune build @doc
	ln -s _build/default/_doc/_html/index.html doc/doc.html

examples: FORCE
	$(MAKE) -C examples/python

FORCE:
