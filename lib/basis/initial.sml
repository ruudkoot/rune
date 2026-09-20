(* The types and exceptions of the initial basis that are not built into the
   compiler. Compiled before every program.
   NOTE: the VM builds option values directly, so NONE must have tag 0 and
   SOME tag 1 (declaration order matters). *)

datatype 'a option = NONE | SOME of 'a
datatype order = LESS | EQUAL | GREATER

exception Fail of string
exception Option
exception Empty
exception Span
exception Unordered
