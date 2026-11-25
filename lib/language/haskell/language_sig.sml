(* The language a module of Haskell is read and checked under (the
   haskell2010 roadmap's D4, D5, D8 and D10): an edition, the Report of
   Haskell 98 or of Haskell 2010, and the set of rhc's features the module
   has, resolved once from the command line and the module's header, as GHC
   resolves them. The edition is a base, the last named winning; a step
   turns a feature on or off, and the steps are replayed over the edition's
   own set in the order they are written, the command line's first, then
   the header's. Every stage asks a module's language whether it has a
   feature (`has`), the lexer and the parser of the file they read, the
   checker and HsLint of the module a binding belongs to; never a setting
   of the run. A unit's key holds each member's set in its canonical form,
   without the edition (`key`), Haskell 98's own set as nothing, so that two
   spellings of one set are one key and a store of Haskell 98's keeps its
   keys.

   A name a command line or a LANGUAGE pragma writes is read by `read`: an
   edition, a feature or its `No` form, or a name rhc does not know. In a
   module whose edition is Haskell 98 the header's names other than the
   editions are not read at all (`ofHeader`, the roadmap's D6), as the 98
   Report asks of a pragma an implementation does not handle; the command
   line's steps apply to every module of the program alike. The library is
   read under its own language, whatever the program's.

   Area: Languages *)
signature HS_LANGUAGE =
sig
  (* The Reports rhc reads a module by. *)
  datatype edition =
      Haskell98
    | Haskell2010

  (* A rule a stage of rhc tests, which a module's language has or not.

     Haskell 2010's are on in its edition, Haskell 98's n+k patterns in
     Haskell 98's; the two settings of a cycle are rhc's own options, set
     from the command line alone (the roadmap's D8), and a cycle's modules
     agree on them. *)
  datatype feature =
      CycleDefaultScc            (* one `default` and Rule 2 for a cycle of modules: --cycle-default=scc (98's D30) *)
    | DoAndIfThenElse            (* `then` and `else` after a semicolon (2010's 3.14) *)
    | EmptyDataDecls             (* a data declaration without constructors (2010's 4.2.1) *)
    | ForeignFunctionInterface   (* `foreign` declarations (2010's chapter 8) *)
    | GreatestFixpointNames      (* a cycle's exports at the greatest fixpoint: --names=greatest (98's D29) *)
    | HierarchicalModules        (* a module name with dots (2010's 5.1), and --dotted-names in 98 (98's D35) *)
    | NPlusKPatterns             (* n+k patterns (98's 3.17.2), which 2010 removes *)
    | PatternGuards              (* a guard of qualifiers (2010's 3.13) *)
    | RelaxedPolyRec             (* a signature cuts a dependency between bindings (2010's 4.5.1) *)

  (* A step of a setting: a feature turned on, or off. *)
  datatype step =
      On of feature
    | Off of feature

  (* A language resolved: its edition and its set of features. *)
  type t

  (* `ofEdition e` is the language of the edition `e`, no step after it. *)
  val ofEdition : edition -> t

  (* `resolve (e, steps)` is the language of the edition `e` with `steps`
     replayed over its own set, the first first.

     A feature a step turns on is in it, one it turns off is not, whatever
     the steps before. *)
  val resolve : edition * step list -> t

  (* `edition t` is the edition of `t`, which only a message names. *)
  val edition : t -> edition

  (* `features t` is the set of `t`, in canonical order. *)
  val features : t -> feature list

  (* `has (t, f)` is whether `t` has the feature `f`. *)
  val has : t * feature -> bool

  (* `same (a, b)` is whether `a` and `b` have one set, whatever their
     editions. *)
  val same : t * t -> bool

  (* `canonical t` is the set of `t` as text: its features' names in order
     of their names, joined by commas, without the edition. *)
  val canonical : t -> string

  (* `key t` is what a unit's key holds of a member under `t`.

     It is nothing where `t`'s set is Haskell 98's own, and its canonical
     form in braces otherwise, the empty set's among them. *)
  val key : t -> string

  (* `editionName e` is the name of `e` that a pragma writes. *)
  val editionName : edition -> string

  (* `featureName f` is the name of `f` in a canonical form and in a
     message: the name a pragma writes, or for rhc's own, the option that
     sets it. *)
  val featureName : feature -> string

  (* ---- Names ---- *)

  (* What a name of a pragma or of `-X` on the command line means. *)
  datatype reading =
      Edition of edition         (* an edition, which replaces the edition *)
    | Steps of step list         (* a feature's name or its `No` form: steps, in order *)
    | Unknown                    (* no name rhc knows *)

  (* `read name` is what `name` means, as it is written: names are
     case-sensitive. *)
  val read : string -> reading

  (* ---- A module's language ---- *)

  (* The setting the command line gives every module of a program: an
     edition and steps.

     The edition is the last it names (`--language=`, `-XHaskell2010`),
     haskell98 where it names none; the steps are in its order (`-X`,
     `--dotted-names`, `--names=`, `--cycle-default=`). *)
  type setting = {edition : edition, steps : step list}

  (* `ofSetting s` is the language the setting `s` gives a module whose
     header names nothing. *)
  val ofSetting : setting -> t

  (* `settingKey s` is the setting `s` as text, nothing for Haskell 98
     with no step: what decides how a header is read beside its text. *)
  val settingKey : setting -> string

  (* A name of the header refused: its offset in the module's text, and
     why. *)
  exception Refused of int * string

  (* `ofHeader (s, names)` is the language of a module under the setting
     `s` whose header's LANGUAGE pragmas write `names`.

     Each name is given with its offset in the module's text, in order. The
     edition is the last the header names, else `s`'s. Where it is Haskell
     98, the header's other names are dropped unread; else each is read, its
     steps after `s`'s.

     Raises: `Refused` for a name rhc does not know, in a module whose
     edition is not Haskell 98, with the name's offset and why (12.3: a
     request rhc cannot honour fails). *)
  val ofHeader : setting * {name : string, at : int} list -> t
end
