(* Desugaring to Core (the haskell98 roadmap's M15, D34): a checked
   program made the Core program it means.

   The program's renamed and resolved trees and the checker's evidence
   records (D31) are translated by chapter 3's translations and 4.4.3's,
   taken literally (`-O0`, D34's A), with dictionaries for classes.

   - Expressions: a literal is `fromInteger` or `fromRational` of its value
     (3.2), but where the checker chose the Prelude's `Int`, `Integer`,
     `Float` or `Double`, whose value it is; `e1 op e2` is `(op) e1 e2`
     and `-e` the Prelude's `negate` (3.4); a section is a lambda, its
     operand bound once outside it (3.5, R11's sharing); `if` a `case` on
     `True` and `False` (3.6); a list the constructors it abbreviates
     (3.7); an arithmetic sequence the method of `Enum` (3.10); a list
     comprehension `concatMap` over a local `ok` (3.11); `let` a `let` or
     a `letrec` by dependency, a pattern binding each of its variables a
     lazy match of its own (3.12, rule (d)); `do` `>>=`, `>>` and `fail`
     (3.14); records by their constructors' fields (3.15); `e :: t` a
     binding of its own scheme (3.16); a string literal unpacked lazily
     by the runtime (D24).
   - Bindings: a function's clauses one lambda of as many parameters as
     its patterns, matched in the Report's order (4.4.3.1, HsMatch); a
     guarded binding falls to the next clause, or for a pattern binding to
     an error (4.4.3.2); a binding the checker generalised a type lambda
     over its variables and a lambda over its dictionaries, in the order
     of its scheme, so that every use is the variable at its types and its
     dictionaries, as the use's record gives them.
   - Classes and instances: a class the data type of its dictionaries,
     with a selector for each method and each direct superclass, and a
     value for each default method; an instance a function of its
     context's dictionaries giving its dictionary, a method it does not
     define its class's default, or an error where there is none (4.3.2).
   - A strict constructor used as a value forces its strict arguments,
     the last first (4.2.1, defect 17); a newtype's constructor is a cast.
   - `main` is the program's main as Core's `main` wants it.

   The names a translation uses are the Prelude's entities, whatever a
   program defines (3, E9): `translationNames` lists them, with Ratio's
   `:%`, for a cache's key (H9).

   Area: Languages *)
signature HS_DESUGAR =
sig
  (* A module of the program: its identity, its renamed tree with fixity
     resolved, and whether it is the library's. *)
  type module_ = {id : string, ast : HsAst.module, library : bool}

  (* `program {modules, infer, evidence, derived, prelude, entity, runtime,
     leaves, main}` is the Core program of the checked `modules`.

     The modules are every module of the program and of the library it
     reaches, whose checking left the environment `infer`, the records
     `evidence` and the methods of the derived instances, `derived`, each
     with its module and its instance's identity (HsDerive, M14), which are
     desugared as a written instance's.

     `prelude` and `entity` find what the translations name (HsDsEnv);
     `runtime` is rhc's runtime in Core, whose types it is written against
     and which it does not repeat; `leaves` are the modules of primitives
     that no file holds, each with what it exports, the runtime's values of
     those names; `main` is the key of the program's `main`. The result
     holds what `main` reaches, and the data types of the program.

     Raises: `Fail` for what the checker should have refused, or a form
     this desugaring does not take, with a message. *)
  val program : {modules : module_ list, infer : HsInfer.env, evidence : HsEvidence.table,
                 derived : (string * string * HsAst.decl list) list, prelude : string * string -> string option, entity : string * string * string -> string,
                 runtime : Core.program, leaves : (string * string list) list, main : string}
                -> Core.program

  (* ---- The library's part, once ----

     `program` is the library's part and then the program's: the first
     declares Core's own types, the leaves' values and every type, class,
     instance and value of the library's modules, and the second those of
     the program's modules and main, against the first. So a saved world
     (D45's B) may make the library's part once, with every body, and each
     program only its own: a value's Core is the same either way, its names
     numbered from the first within it (HsDsCore.canonical) and a pattern
     binding of the top level named after its first variable. *)

  (* The library's part: what its declarations left known, its types and
     its values, each value's body made the first time it is wanted. *)
  type library

  (* `library p` is the library's part of the modules of `p` marked
     `library`.

     `p` is a checking of the library alone (every instance of its
     environment is the library's), in `program`'s form without `main`. *)
  val library : {modules : module_ list, infer : HsInfer.env, evidence : HsEvidence.table,
                 derived : (string * string * HsAst.decl list) list, prelude : string * string -> string option,
                 entity : string * string * string -> string, runtime : Core.program, leaves : (string * string list) list}
                -> library

  (* `prepare lib` makes every body of `lib` now, as a saved world keeps
     them; a body that fails is failed again where a program reaches it. *)
  val prepare : library -> unit

  (* `programOn (lib, p)` is `program` of `p` with the library's part
     `lib`: the modules of `p` not marked `library` desugared against it.

     The modules, environment, records and derived instances of `p` are the
     whole checking's, the library's among them, as `program` takes them;
     a value of the library is `lib`'s. *)
  val programOn : library * {modules : module_ list, infer : HsInfer.env, evidence : HsEvidence.table,
                             derived : (string * string * HsAst.decl list) list,
                             prelude : string * string -> string option, entity : string * string * string -> string,
                             main : string}
                  -> Core.program

  (* `translationNames` is each entity the translations name, by its
     space, its module and its name. *)
  val translationNames : (string * string * string) list

  (* `missingPrimitives ()` is each primitive of the library that the last
     desugaring found neither in Core nor in the runtime, or of another
     type.

     It is of the bodies the desugaring made, the library's made once among
     them.

     Each is an error where it is used. *)
  val missingPrimitives : unit -> string list
end
