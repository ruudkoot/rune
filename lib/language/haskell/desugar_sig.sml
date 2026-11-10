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

  (* `program {modules, groups, infer, evidence, derived, prelude, entity,
     runtime, leaves, main}` is the Core program of the checked `modules`.

     The modules are every module of the program and of the library it
     reaches, in `groups`, their strongly connected groups by identity in
     order, each desugared as a unit after those before it (`unit`). Their
     checking left the environment `infer`, the records `evidence` and the
     methods of the derived instances, `derived`, each with its module and
     its instance's identity (HsDerive, M14), which are desugared as a
     written instance's.

     `prelude` and `entity` find what the translations name (HsDsEnv);
     `runtime` is rhc's runtime in Core, whose types it is written against
     and which it does not repeat; `leaves` are the modules of primitives
     that no file holds, each with what it exports, the runtime's values of
     those names; `main` is the key of the program's `main`. The result
     holds what `main` reaches, and the data types it names, each body made
     only where `main` reaches it.

     Raises: `Fail` for what the checker should have refused, or a form
     this desugaring does not take, with a message. *)
  val program : {modules : module_ list, groups : string list list, infer : HsInfer.env, evidence : HsEvidence.table,
                 derived : (string * string * HsAst.decl list) list, prelude : string * string -> string option,
                 entity : string * string * string -> string, runtime : Core.program, leaves : (string * string list) list,
                 main : string}
                -> Core.program

  (* ---- Units (M21) ----

     A unit is a strongly connected group of modules, desugared after the
     units before it from their interfaces alone: every type, class,
     instance and value its modules declare, a value's Core the same in
     every unit and in the whole program, its names numbered from the first
     within it (HsDsCore.canonical) and a pattern binding of the top level
     named after its first variable. The first unit also declares Core's
     own types the desugaring makes (IO's newtype, `()`, `[]`, the tuples
     to 15), the raisers (HsDsCore.raisers) and the leaves' values. *)

  (* What a unit's desugaring leaves the units after it.

     `core` is its types and its values as imports (`(import x TYPE)`);
     `primTypes` each type of the library with no constructor, by key, made
     Core's own, and `builtinCons` Bool's constructors, Core's; `fields`
     each constructor's fields' keys (`""` for one with no name), and
     `constructors` each data type's constructors' keys, in order; `leaves`
     the keys of the leaves' values, and `defaults` the methods with a
     default (a `%dm:` value). *)
  type interface = {core : Core.program, primTypes : (string * string) list, builtinCons : (string * string) list,
                    fields : (string * string list) list, constructors : (string * string list) list,
                    leaves : string list, defaults : string list}

  (* `unit p` is the Core of the unit of the modules of `p`, after the units
     of its interfaces, in order, and its interface.

     The Core is its types, a copy of each type of the units before that it
     names, an import of each of their values that it names, and every
     value it defines; the runtime's names are left to the runtime's unit.
     `infer` and `evidence` are a checking that holds the unit's modules and
     what they import; `leaves` is the first unit's, and `main`, the key of
     the program's `main`, the unit's that defines it, whose Core then has
     Core's `main`. The rest is as `program` takes it. *)
  val unit : {interfaces : interface list, modules : module_ list, infer : HsInfer.env, evidence : HsEvidence.table,
              derived : (string * string * HsAst.decl list) list, prelude : string * string -> string option,
              entity : string * string * string -> string, runtime : Core.program, leaves : (string * string list) list,
              main : string option}
             -> Core.program * interface

  (* ---- The library's units, once ---- *)

  (* The library's units, desugared once (D45's saved world), each value's
     body made the first time it is wanted. *)
  type library

  (* `library p` is the units of the groups of `p` that hold modules marked
     `library`.

     `p` is a checking of the library alone (every instance of its
     environment is the library's), in `program`'s form without `main`. *)
  val library : {modules : module_ list, groups : string list list, infer : HsInfer.env, evidence : HsEvidence.table,
                 derived : (string * string * HsAst.decl list) list, prelude : string * string -> string option,
                 entity : string * string * string -> string, runtime : Core.program, leaves : (string * string list) list}
                -> library

  (* `prepare lib` makes every body of `lib` now, as a saved world keeps
     them; a body that fails is failed again where a program reaches it. *)
  val prepare : library -> unit

  (* `programOn (lib, p)` is `program` of `p` with the library's units
     `lib`: the groups of `p` that hold no module of the library desugared
     after them.

     The modules, environment, records and derived instances of `p` are the
     whole checking's, the library's among them, as `program` takes them;
     a value of the library is `lib`'s. *)
  val programOn : library * {modules : module_ list, groups : string list list, infer : HsInfer.env,
                             evidence : HsEvidence.table, derived : (string * string * HsAst.decl list) list,
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
