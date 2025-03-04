include ../../../Makefile.include

OPTIMIZE_FLAG=-O

MLANG_BIN=dune exec --no-print-director ../../../src/main.exe --

MLANG_DEFAULT_OPTS=\
	--display_time --debug \
	--mpp_file=$(MPP_FILE) \
	--mpp_function=compute_double_liquidation_pvro

MLANG=$(MLANG_BIN) $(MLANG_DEFAULT_OPTS) $(OPTIMIZE_FLAG)

##################################################
# Generating the tests.m_spec
##################################################

tests.m_spec: gen_m_spec.py
	python3 $< $(TESTS_DIR) $@

##################################################
# Generating the C code
##################################################

ir_%.c: ../../../m_specs/%.m_spec $(SOURCE_FILES)
	$(MLANG) \
		--backend c --output $@ \
		--function_spec $< \
		$(SOURCE_FILES)
ir_%.c: %.m_spec $(SOURCE_FILES)
	$(MLANG) \
		--backend c --output $@ \
		--function_spec $< \
		$(SOURCE_FILES)

.SECONDARY: ir_%.c ir_%.h
.PRECIOUS: ir_%.c ir_%.h

##################################################
# Compiling the generated C
##################################################

C_COMPILER?=clang
CC=$(C_COMPILER)

ifeq ($(C_COMPILER), clang)
    F_BRACKET_OPT=-fbracket-depth=2048
else
    F_BRACKET_OPT=
endif

ir_%.o: export AFL_DONT_OPTIMIZE=1
ir_%.o: ir_%.c
	$(CC) -I ../ $(F_BRACKET_OPT) $(C_OPT) -c -o $@ $<

%.o: %.c
	$(CC) -I ../ -O3 -c -o $@ $<

##################################################
# Building and running the test harness
##################################################

test_harness.exe: ir_tests.o test_harness.o ../m_value.o
	$(CC) -fPIE -lm -o $@ $^

run_tests: test_harness.exe FORCE
	ulimit -s 32768; \
	./$< $(TESTS_DIR)

perf_harness.exe: ir_tests.o perf_harness.o ../m_value.o
	$(CC) -fPIE -lm -o $@ $^

run_perf: perf_harness.exe FORCE
	ulimit -s 32768; \
	time ./$< $(ONE_TEST_FILE)

##################################################
# Building and running the fuzzing harness
##################################################

FUZZ_M_SPEC=tests

fuzz_harness.exe: CC=afl-$(C_COMPILER)
fuzz_harness.exe: ir_$(FUZZ_M_SPEC).o fuzz_harness.o ../m_value.o
	$(CC) -fPIE -lm -o $@ $^

AFL_FUZZ=afl-fuzz

ifeq ($(JOB_NO), 0)
	AFL_JOB_FLAG=-M fuzzer$(JOB_NO)
else
	AFL_JOB_FLAG=-S fuzzer$(JOB_NO)
endif

# First, you launch the fuzzerrs
# Usage: JOB_NO=<0,1,2...> make launch_fuzz
launch_fuzz: fuzz_harness.exe
	ulimit -s 32768; \
	$(AFL_FUZZ) -i fuzz_inputs -o fuzz_findings \
		-m 500 -t 1000 $(AFL_JOB_FLAG) \
		-- ./fuzz_harness.exe @@

# When they're done, you have to rename all crashes found into more
# palatable names. This creates the fuzz_tests directory.
#Usage: make sanitize_crash_names
sanitize_crash_names: FORCE
	./sanitize_crash_names.sh

# Then, you can minimize the test corpus to only keep a minimal
# amount of test cases with an optimal coverage
minimize_test_corpus: FORCE
	mkdir -p fuzz_tests_minimized
	afl-cmin -C -i fuzz_tests -o fuzz_tests_minimized -- ./fuzz_harness.exe @@

# As a funal step, you have to transform the renamed crash files into Mlang test cases
# with the right format. For that use transform_crashes_into_tests
FUZZER_CRASHES=$(shell find fuzz_tests_minimized/ -name "*.m_crash" 2> /dev/null)

%.m_test: %.m_crash FORCE
	-stdbuf -oL bash -c "./fuzz_harness.exe $< > $@"

# Usage: make transform_crashes_into_tests
transform_crashes_into_tests: $(patsubst %.m_crash,%.m_test,$(FUZZER_CRASHES))

process_fuzzer_results: sanitize_crash_names minimize_test_corpus transform_crashes_into_tests

clean_fuzz_findings:
	rm -rf fuzz_findings/*
clean_fuzz_tests:
	rm -rf fuzz_tests/*.m_crash

clean:
	rm -f ir_tests.* ../m_value.o *.o tests.m_spec *.exe *.tmp

FORCE:
