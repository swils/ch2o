# This Makefile is designed with two use cases in mind:
#
# 1. building and installing (typically as part of installing an Opam package);
# 2. building for local development.

MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
ROOT_DIR := $(dir $(MAKEFILE_PATH))

# The CH2O executable makes use of a number of headers that are shipped with
# CH2O (`limits.h`, `stdddef.h`, ... located in `include`). The location of
# these files is currently hardcoded in the ch2o executable. The Makefile
# variable INSTALL_DIR_INCLUDE controls this hardcoding. This is not ideal,
# but for now it is good enough to support our two use cases.
#
# When building as an Opam package (meaning `make install` will be executed),
# INSTALL_DIR_INCLUDE must refer to the final location into which they will
# be copied. When installing as an Opam package, the opam file sets its value
# as an environment variable, which is then copied into a Makefile variable.
#
# When building for local development (meaning `make install` will not be
# executed), this variable just refers by default to their current location
# in the source folder (include). In this scenario, you never need to bother
# with setting INSTALL_DIR_INCLUDE manually. They are just left in their place.
INSTALL_DIR_INCLUDE ?= $(ROOT_DIR)include

# Default target.
all: lib ch2o
.PHONY: all

lib: Makefile.coq
	+@$(MAKE) -f Makefile.coq all
.PHONY: lib

# Create the CH2O command line tool. Taken from the original SConstruct file.
# Creating file `Include.ml` from this Makefile is probably not a good idea, we
# should improve this.
#
# There is a dependency on building the Coq code, related to code extraction.
#
# The resulting binary is copied into the project main directory.
ch2o: lib
	echo "let include_dir = ref \"$(INSTALL_DIR_INCLUDE)\"" > parser/Include.ml
	ocamlbuild -j 2 -libs nums,str,unix -I parser parser/Main.native parser/Main.byte
	cp _build/parser/Main.native ch2o

# Create Coq Makefile.
Makefile.coq: _CoqProject Makefile
	"$(COQBIN)coq_makefile" -f _CoqProject -o Makefile.coq $(EXTRA_COQFILES)

# Target `clean` forwards `clean` to the Coq Makefile, but also ends up
# deleting that very same Coq Makefile afterwards.
clean: Makefile.coq
	+@$(MAKE) -f Makefile.coq clean
	rm -f Makefile.coq
	rm -f Makefile.coq.conf
	rm -f Makefile.coq.d
	@# Make sure not to enter the `_opam` folder.
	find [a-z]*/ \( -name "*.d" -o -name "*.vo" -o -name "*.vo[sk]" -o -name "*.aux" -o -name "*.cache" -o -name "*.glob" -o -name "*.vio" \) -print -delete || true
	rm -f .lia.cache
	rm -f builddep/*
	rm -f parser/Include.ml
	rm -f parser/Extracted.*
	rm -rf _build
	rm -f ch2o
.PHONY: clean

install: lib ch2o
	+@$(MAKE) -f Makefile.coq install
	cp ch2o $(INSTALL_DIR_BIN)/ch2o
	mkdir -p $(INSTALL_DIR_INCLUDE)
	cp include/* $(INSTALL_DIR_INCLUDE)
.PHONY: install

# Forward most targets to Coq makefile (with some trick to make this phony).
%: Makefile.coq phony
	@#echo "Forwarding $@"
	+@$(MAKE) -f Makefile.coq $@
phony: ;
.PHONY: phony

# Some files that do *not* need to be forwarded to Makefile.coq.
# ("::" lets Makefile.local overwrite this.)
Makefile Makefile.local _CoqProject $(OPAMFILES):: ;
