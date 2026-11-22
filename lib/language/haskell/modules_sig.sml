(* The names of Haskell 98's modules (the Report's chapter 5; the haskell98
   roadmap's D29, D30): what each module defines, what it exports, and what
   is in scope in it, over a group of modules that import one another.

   An entity is a thing a name can stand for: its name space, the module
   that defines it, by that module's identity, and its name. A name stands
   for zero, one or several entities, and is an error only where it is used
   and stands for other than one, in the manner of Diatchki, Jones and
   Hallgren 2002. Within a strongly connected group of modules the exports
   and the scopes are defined by each other, and are solved by iteration:
   from nothing, the least fixpoint (D29's A, the default), or from
   everything, the greatest. Instances are not names, and every instance a
   program declares is visible in all of it.

   Area: Languages *)
signature HS_MODULES =
sig
  (* The two name spaces: values (variables, constructors, fields,
     methods) and types (type constructors, synonyms, classes). *)
  datatype space = Value | Type

  (* An entity: its space, the identity of the module that defines it, and
     its name.

     A module's identity is its name for a module of the program, and its
     library's name, a colon and its name for a library's: a program's
     `Char` is not the library's. *)
  type entity = {space : space, home : string, name : string}

  (* `key e` is `e` as a string, unique to it, for maps and sets. *)
  val key : entity -> string

  (* `moduleName id` is the name of the module of identity `id`, without
     its library. *)
  val moduleName : string -> string

  (* What a top-level definition is. *)
  datatype sort =
      Var        (* a variable *)
    | Con        (* a data constructor *)
    | Field      (* a field of a record *)
    | Method     (* a class's method *)
    | TyCon      (* a type constructor of `data` or `newtype` *)
    | Synonym    (* a type synonym *)
    | Class      (* a class *)

  (* A top-level definition: its entity, what it is, and where it is.

     With them, the type or class it belongs to, for a constructor, a field
     or a method, and the number of arguments a constructor takes. *)
  type def = {entity : entity, sort : sort, parent : entity option, arity : int, span : HsSource.span}

  (* `defs (id, m)` is what the module `m` of identity `id` defines at its
     top level, each once, in the order of the source. *)
  val defs : string * HsAst.module -> def list

  (* A module as resolution reads it: its identity, its name, its tree,
     and its imports.

     Each import has the identity of the module it names, the implicit
     import of the Prelude among them where the module has one. *)
  type unit_ = {id : string, name : string, ast : HsAst.module, imports : (HsAst.import * string) list}

  (* What is in scope in a module: the entities a name stands for, by
     `scopeKey`. *)
  type scope = entity list HsStringMap.map

  (* `scopeKey (space, qual, name)` is the key of the name `name` qualified
     by `qual`, `""` for none, in the space `space`. *)
  val scopeKey : space * string * string -> string

  (* `lookup (scope, space, qual, name)` is the entities the name stands
     for: none, one, or several. *)
  val lookup : scope * space * string * string -> entity list

  (* The fixpoint to take where a group's exports admit several. *)
  datatype fixpoint = Least | Greatest

  (* What `solve` makes of a group: each module's exports and scope, by
     identity, and the errors of the group's export and import lists. *)
  type solved = {exports : entity list HsStringMap.map, scopes : scope HsStringMap.map,
                 errors : (HsSource.span * string) list}

  (* `solve {group, exportsOf, defOf, universe, fixpoint}` solves the
     exports and the scopes of the strongly connected group of modules
     `group`.

     `exportsOf id` gives the exports of a module outside the group,
     solved before it, `defOf` gives the definition of every entity of the
     program, by `key`, and `universe` is every entity of the program,
     from which the greatest fixpoint starts. The errors are
     those of chapter 5: an export of what is not in scope, of a module
     that is not imported, two entities exported under one name, an import
     of what a module does not export. *)
  val solve : {group : unit_ list, exportsOf : string -> entity list, defOf : string -> def option,
               universe : entity list, fixpoint : fixpoint} -> solved
end
