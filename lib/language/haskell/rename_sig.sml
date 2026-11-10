(* Haskell 98's renamer (the haskell98 roadmap's M12): every name of a
   module's tree resolved to what it stands for, in the scope that
   `HsModules` gives the module and the scopes its own bindings make.

   The renamed tree is a tree of `HsAst`, with every name rewritten: a name
   of the top level is its entity, qualified by the identity of the module
   that defines it (`{qual = home, name = name}`), and a local one, a
   variable a pattern or a local declaration binds, is unqualified and made
   unique with a `#` and a number, which no name of the source can hold.
   Type variables and the built-in names (`()`, `[]`, `:`, the tuples',
   `(->)`) stay as they are written. The static checks that need names
   are made here: a name in scope, and standing for one entity; a
   constructor applied to as many patterns as it takes; one definition of a
   name in a group of bindings, its clauses together; a signature or a
   fixity declaration only for what its group defines; an instance's method
   one of its class's.

   Area: Languages *)
signature HS_RENAME =
sig
  (* The associativity and the precedence of an operator. *)
  type fixity = HsAst.fixity * int

  (* What a module's renaming gives: the tree, the fixities declared for
     its local operators, by their unique names, and the errors, in the
     order of the source. *)
  type renamed = {module : HsAst.module, localFixities : fixity HsStringMap.map,
                  errors : (HsSource.span * string) list}

  (* `rename {id, scope, defOf} m` renames the module `m` of identity
     `id`, whose scope is `scope`, where `defOf` gives the definition of
     every entity of the program by `HsModules.key`. *)
  val rename : {id : string, scope : HsModules.scope, defOf : string -> HsModules.def option}
               -> HsAst.module -> renamed

  (* `topFixities (id, m)` is the fixities that the module `m` of identity
     `id` declares at its top level and in its classes, by the key of the
     operator's entity. *)
  val topFixities : string * HsAst.module -> (string * fixity) list
end
