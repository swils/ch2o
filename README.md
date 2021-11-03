# CH2O

## Prerequisites

This version is known to compile with:

 - Coq 8.13.2
 - SCons 4.0.1.post1
 - OCaml 4.12
 - OCaml-Num 1.4.2
 - OCamlbuild 0.14.0
 - GNU C preprocessor 8.3.0

To set this up using OPAM:

```
$ opam switch create . 4.12.0
$ eval $(opam env)
$ opam install ocamlbuild
$ opam repo add coq-released https://coq.inria.fr/opam/released
$ opam install coq.8.13.2
```

## Building instructions

Say `scons` to build the full library, or `scons some_module.vo` to just 
build `some_module.vo` (and its dependencies).

In addition to common Make options like `-j N` and `-k`, SCons supports some 
useful options of its own, such as `--debug=time`, which displays the time 
spent executing individual build commands.

`scons -c` replaces `Make clean`.