(* HsLint (the haskell98 roadmap's M16, D54): the independent check of
   rhc's types, as AstLint is Rune's. Its first part is a second
   inference: a transliteration of Typing Haskell in Haskell (Jones 1999)
   in the form its 11.6.3 calls conformant, with kinds and dependency
   groups recomputed, the monomorphism restriction and defaulting as the
   roadmap's D32 reads the Report (R18, R20, R21, R22), over the renamed
   tree. It shares nothing with rhc's checker but the renamer: its
   unifier, its kinds and its context reduction are its own, so that a
   disagreement between the two is a finding. rhc runs it among the
   checks of level 2 (`--lint=2`, `RUNE_LINT=2`), where a refusal of a
   program the compile accepts is a bug of rhc's.

   Area: Languages *)
signature HS_LINT =
sig
  (* A module of a program as HsLint reads it: its identity, its tree as
     `HsRename` renamed it and `HsFixity` resolved it, and whether it is
     one of rhc's library's. *)
  type module = {id : string, ast : HsAst.module, library : bool}

  (* A binding of the top level as the second inference left it: its
     module, its name, its type as text, whether a signature declared it.

     `restricted` is whether its group is restricted (4.5.5, Rule 1). The
     type is written as the Report writes one, `Eq a => [a] -> a -> Bool`. *)
  type binding = {module : string, name : string, scheme : string, signed : bool, restricted : bool,
                  span : HsSource.span}

  (* A default the second inference chose (4.3.4): the module, where, the
     predicates it resolved and the type, as text.

     `ruleTwo` is whether Rule 2 chose it, where the module was inferred. *)
  type default = {module : string, span : HsSource.span, preds : string, choice : string, ruleTwo : bool}

  (* The kind inferred for a type constructor or a class's variable (4.6):
     the module, the name and the kind, as text. *)
  type kind = {module : string, name : string, kind : string}

  (* A class by its name: whether it is numeric and standard (4.3.4). *)
  type class_ = {name : string, numeric : bool, standard : bool}

  (* A derived instance with the context inferred for it (4.3.3, 10.1):
     the module of its type, and the instance as text, `Eq a => Eq (T a)`. *)
  type derived = {module : string, instance : string}

  (* What the second inference found: bindings, defaults, kinds, derived
     instances and classes.

     The bindings of the top level of every module and the defaults are in
     the order it met them; the kinds are of the type constructors and the
     classes. *)
  type report = {bindings : binding list, defaults : default list, kinds : kind list, derived : derived list,
                 classes : class_ list}

  (* A refusal of the second inference: where, and why, the why naming the
     row of the conformance table it is for where there is one. *)
  exception Refused of HsSource.span * string

  (* `infer {groups, main, cycleDefault}` is the report of the second
     inference over the program whose groups of modules are `groups`.

     The groups are the strongly connected ones, dependencies first;
     `main` is the identity of the module whose `main` must have the type
     `IO t` (5), if any; and `cycleDefault` is whether a group's modules
     share one `default` and Rule 2 closes at the group's end (D30's
     `--cycle-default=scc`) rather than each module's.

     Raises: `Refused` at the first breach of the Report's static rules
     the second inference finds. *)
  val infer : {groups : module list list, main : string option, cycleDefault : bool} -> report

  (* What a record claims of a program, in the form `dump` prints.

     The claims are kinds, derived instances, the types of the bindings of
     its modules' top levels and the defaults. *)
  type claims

  (* `claims text` is the claims of `text`, lines in the form of `dump`;
     a line of another form claims nothing. *)
  val claims : string -> claims

  (* `rules` is each rule of `compare` with what it holds, its name being
     the first word of its breach's message, in brackets: `[rule1] ...`. *)
  val rules : (string * string) list

  (* `compare (report, claims, where_, fault)` holds the claims to the
     report, of the program's modules, `where_` giving a default's place.

     `fault`, a rule's name or "", reads the first claim that rule checks
     corrupted, so that the rule must refuse it.

     Raises: `Refused` at the first claim a rule refuses. *)
  val compare : report * claims * (HsSource.span -> string) * string -> unit

  (* `replayRules` is each rule of replay with what it holds (Faxén's
     rules and rhc's), its name the first word of its breach's message, in
     brackets: `[bindg] ...`. *)
  val replayRules : (string * string) list

  (* `check {groups, main, cycleDefault, records, claims, where_, fault}`
     is `infer`'s report, the checker's records replayed and compared.

     With `records`, the checker's evidence records and environment
     (HsEvidence, HsInfer), each record is replayed by Faxén's rules and
     rhc's (`replayRules`), and the records are then held to the
     inference as claims (`compare`); with `claims`, those are too.
     `fault` is as `compare`'s, for every rule.

     Raises: `Refused` at the first breach. *)
  val check : {groups : module list list, main : string option, cycleDefault : bool,
               records : {table : HsEvidence.table, env : HsInfer.env} option, claims : claims option,
               where_ : HsSource.span -> string, fault : string} -> report

  (* `dump (report, where_, library)` is the report as text, a line each.

     The lines are `KIND MODULE NAME :: KIND` for a type constructor or a
     class, `DERIVED MODULE INSTANCE`, `TYPE MODULE NAME :: TYPE` for a
     binding, `SIGNED` for one with a signature, and `DEFAULT MODULE WHERE
     PREDS -> TYPE`, where `where_` gives a span's place: of the program's
     modules, and of the library's too where `library` is set, but its
     signed bindings. *)
  val dump : report * (HsSource.span -> string) * bool -> string
end
