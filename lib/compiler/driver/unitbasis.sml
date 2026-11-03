(* The export basis of a unit, as bytes (docs/units.md, *The export basis*;
   the incremental roadmap's D3, D4 and M6): what the units after it need
   of it to be compiled -- the environment it declared, its fixity
   directives, signatures, functors and overloading, and the compiler's
   tables of what it declared: each value's scheme, each exception's
   argument, each datatype's constructors, what each opaque type stands for,
   the primitives some values are, the functions that may be called by
   name -- in a form that does not depend on what was compiled before it.

   Every name -- a stamp (Elaborate.stampCounter: values, exceptions and the
   variables of the IRs), a type name (Types.tyconCounter), a type variable
   (Types.tvarCounter) -- is written as one of three:
   * a built-in one, made before any unit, as itself;
   * one of this unit's own, by a number of its own, given in the order the
     writing meets them, so that the same declarations always get the same
     numbers whatever came before (D3: Elsman's equality up to renaming);
   * one of an earlier unit's, by its place in the unit's imports, a table of
     each kind that says the earlier unit's identity and its number there.
   Loading a unit gives its numbers names of the session again, a range of
   each kind after everything before it, and registers the range, so that
   the units after it name what it declared by its identity.

   A unit's identity is its name and the hash of its basis without the
   counts of what its compile used and with no unit's identity in it: an
   earlier unit's name is hashed as what it is, its anchor and fingerprint
   (importsHash), and its unit and number, which may be others for the same
   thing, are in a table of the unit's imports that no hash covers. So a
   unit whose body changed and whose basis did not keeps its identity, and
   what was compiled against it stays valid (the cut-off), and so does a unit
   whose imports changed in nothing it names: what a compile may read of
   an earlier unit through this one is what this one names of it. Every
   unit of a compile in units is loaded this way right after it is compiled
   (Main, the REPL), and the units after it see only
   what the bytes say: a unit compiled now and one taken from the cache are
   the same to them, byte for byte.

   A basis is two layers, each its own bytes, read side by side: the static
   layer, what elaboration reads -- names, types, signatures, functors'
   signatures, fixity, constructors and how they lie -- and the ABI layer, what
   a client's code is built on: value and exception names, flags, facts by
   stamp, bodies to copy, realisations. The static layer is written first and
   nothing in it depends on the other, so a compile and an analysis that
   elaborate alike write the same bytes of it; only the first has anything to
   write in the second.

   Where a name was bound, its origin, is the editor's and nobody else's: a
   unit's origins are written to a sidecar, apart from its basis and from
   every hash, and read beside it in the same order, so that a comment that
   moves a span moves no identity (docs/units.md). A batch compile records
   none, and its sidecar is empty. The one position a basis keeps is that of
   a body kept for a later unit to copy, whose line table the copy's code
   holds (linePosition).

   A functor is written as its signature and the global of its function,
   to which it is compiled: nothing of its body, which loading needs not;
   a functor marked to be inlined, its function's Mid as well (funcode). *)
structure UnitBasis =
struct
  structure P = Pickle
  structure T = Types

  (* a pickle that names a unit the session has not loaded *)
  exception Missing of string
  (* the scheme of a global a unit taken from the cache names is another than
     its compile had (importedSchemes, schemesHold) *)
  exception SchemeChanged of string

  (* 16: origins in a sidecar of their own, outside the bytes an identity
     hashes; 17: of a copied body the hash alone of what only a hash reads;
     18: another unit's names by a table of the unit's imports, and the
     identity worked out with what they are, not with the units' identities;
     19: the static layer, written whole before the ABI layer; 20: an
     environment with origins may be a reference, as one with none; 21: a
     reference's stamps and flags as runs; 22: a reference's unit by its place
     among those the static layer refers to; the origins of a reference only
     where they are not its structure's; 23: a reference's stamps that an
     earlier reference of the unit has by the place of that one's *)
  val version = 23
  val magic = "RBI"

  (* ---- the kinds of names ---- *)
  val kStamp = 0
  val kTycon = 1
  val kTvar = 2
  fun counter k = if k = kStamp then Elaborate.stampCounter else if k = kTycon then T.tyconCounter else T.tvarCounter
  fun counters () = Vector.tabulate (3, fn k => !(counter k))
  fun setCounters (v : int vector) = Vector.appi (fn (k, c) => counter k := c) v

  fun bug msg = raise Fail ("UnitBasis: " ^ msg)

  (* ---- the units of the session ---- *)

  (* A unit loaded: its identity, its name, the name its source has in
     spans, where its numbers start in the session, and how many of each
     kind. *)
  type loaded = {identity : string, name : string, file : string, base : int vector, count : int vector}

  val units : loaded list ref = ref []                        (* newest first *)
  val () = CompilerState.cellRoot ("UnitBasis.units", units)
  val byIdentity : loaded StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("UnitBasis.byIdentity", byIdentity)
  (* every name below these is built in *)
  val builtin : int vector ref = ref (Vector.fromList [0, 0, 0])
  val () = CompilerState.cellRoot ("UnitBasis.builtin", builtin)
  (* per kind, the ranges of the units by base, for writing: (base, count,
     unit), in pieces whose lengths are powers of two, the newest and shortest
     first, so that a unit added costs the log of the units and not their
     number *)
  val ranges : (int * int * loaded) vector list array = Array.array (3, [])
  val () = CompilerState.arrayRoot ("UnitBasis.ranges", ranges)
  fun addRange (pieces, range) =
    let fun carry (piece, older :: rest) =
              if Vector.length older <= Vector.length piece then carry (Vector.concat [older, piece], rest)
              else piece :: older :: rest
          | carry (piece, []) = [piece]
    in carry (Vector.fromList [range], pieces) end
  (* the unit whose range of kind k holds v *)
  fun rangeOf (k, v) : (int * loaded) option =
    let
      fun search (rs, lo, hi) =
        if lo >= hi then NONE
        else
          let
            val mid = (lo + hi) div 2
            val (b, c, u) = Vector.sub (rs, mid)
          in
            if v < b then search (rs, lo, mid)
            else if v >= b + c then search (rs, mid + 1, hi)
            else SOME (b, u)
          end
      fun piece [] = NONE
        | piece (rs :: older) =
            if v >= #1 (Vector.sub (rs, 0)) then search (rs, 0, Vector.length rs) else piece older
    in piece (Array.sub (ranges, k)) end
  (* the type variables of the units loaded, by their ids: one cell for each *)
  val tvars : T.tvar ref IntTable.table ref = ref (IntTable.table 1024)
  val () = CompilerState.refRoot ("UnitBasis.tvars", tvars, IntTable.copy)

  (* Who bound each name of the top level the session has, by its kind and
     name as Usage records them ("v x", "s A", "fix ++", ...): the identity of
     the unit; a name not here is the initial basis's *)
  val binders : string StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("UnitBasis.binders", binders)

  (* The name of a stamp of kind k that is the same from session to
     session, and in a unit taken from the cache: built in, or the unit's
     identity and its place among the unit's own; NONE for one of the unit
     being compiled, whose identity is not known yet *)
  fun stableName (k : int, n : int) : string option =
    if n < Vector.sub (!builtin, k) then SOME ("b" ^ Int.toString n)
    else
      case rangeOf (k, n) of
        SOME (b, {identity, ...}) => SOME (identity ^ "#" ^ Int.toString (n - b))
      | NONE => NONE
  val () = Translate.printerKey := (fn s => stableName (kTycon, s))
  (* overloading resolved at a type is a usage of the type's registration,
     by the type's name ("o NAME"), which the unit that registered it binds *)
  val () = Overload.used := (fn (c : T.tycon) =>
                               if !Usage.recording
                               then Option.app (fn n => Usage.use ("o", n)) (stableName (kTycon, #stamp c))
                               else ())

  (* A session begins: what exists now is built in. *)
  (* each usage's fingerprint, by its binder and key, once worked out
     (fingerprintAt) *)
  (* M6b: the hash of each inlined functor's Mid, by its function's global
     (the usage "inl NAME"), which its basis keeps: what makes it is the body
     and what the copies take of the globals it names, and that a reader
     would only throw away (bodyHash); and the names a read function's own
     names get, below 0, each read its own *)
  val inlineHashes : string IntTable.table ref = ref (IntTable.table 16)
  val () = CompilerState.refRoot ("UnitBasis.inlineHashes", inlineHashes, IntTable.copy)
  fun inlineHash (g : int) : string option = IntTable.find (!inlineHashes, g)
  val privateNext = ref ~2
  val () = CompilerState.cellRoot ("UnitBasis.privateNext", privateNext)
  val fpMemo : string option StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("UnitBasis.fpMemo", fpMemo)
  (* the static layer's fingerprints of the type names, as tyconFps below *)
  val staticTycons : string IntTable.table ref = ref (IntTable.table 64)
  val () = CompilerState.refRoot ("UnitBasis.staticTycons", staticTycons, IntTable.copy)
  (* RUNE_STATIC_LOAD: a load in a compile that makes no code enters nothing of
     the ABI layer in the compiler's tables: what a reader of the static
     layer alone gets, which must be what elaboration needs (docs/units.md) *)
  val staticLoad = ref false
  val () = CompilerState.cellRoot ("UnitBasis.staticLoad", staticLoad)
  (* RUNE_LAYER_DUMP=DIR: each export's hashes, by unit (dumpLayers) *)
  val layerDump : string option ref = ref NONE
  val () = CompilerState.cellRoot ("UnitBasis.layerDump", layerDump)
  (* what an import that is a value is, by stamp, once worked out (importStamp) *)
  val stampFps : string IntTable.table ref = ref (IntTable.table 64)
  val () = CompilerState.refRoot ("UnitBasis.stampFps", stampFps, IntTable.copy)
  (* the fingerprints of the signatures' structures that a usage's stream
     names by reference (fpChild), by mode, unit, signature and path, once
     worked out (functors-units M11) *)
  val refMemo : string StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("UnitBasis.refMemo", refMemo)
  (* each loaded unit's signatures, by its identity and their names *)
  val unitSigs : SigMatch.sigma StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("UnitBasis.unitSigs", unitSigs)
  (* the text of a global's scheme (schemeText), by its stamp, once worked
     out in a session *)
  val schemeMemo : string option IntMap.map ref = ref IntMap.empty
  val () = CompilerState.cellRoot ("UnitBasis.schemeMemo", schemeMemo)
  (* of those: each signature's own type names by their places, and each
     structure's in the order of their first occurrence in it, by unit,
     signature (and path), once worked out *)
  val sigLocals : int IntMap.map StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("UnitBasis.sigLocals", sigLocals)
  val targetOrders : int list StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("UnitBasis.targetOrders", targetOrders)
  (* the templates a basis's references to those structures are read
     from, by the same keys (makeTemplate) *)
  datatype tnode = NVar | NCon of T.tycon * int list | NRec of (string * int) list | NArr of int * int
  type template = {nodes : tnode vector, orig : T.ty vector, owned : bool vector, slots : int vector}
  val templates : template StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("UnitBasis.templates", templates)

  (* a session of units begins: in the driver, the REPL and the compiler
     library alike, whose units' Mid the lint checks against the schemes of
     the globals of the units before them, which ToMid keeps *)
  fun startSession () =
    (units := []; byIdentity := StringMap.empty; builtin := counters ();
     Array.modify (fn _ => []) ranges; tvars := IntTable.table 1024; binders := StringMap.empty;
     fpMemo := StringMap.empty; refMemo := StringMap.empty; unitSigs := StringMap.empty; schemeMemo := IntMap.empty;
     stampFps := IntTable.table 64; staticTycons := IntTable.table 64; layerDump := OS.Process.getEnv "RUNE_LAYER_DUMP";
     staticLoad := isSome (OS.Process.getEnv "RUNE_STATIC_LOAD");
     sigLocals := StringMap.empty; targetOrders := StringMap.empty; templates := StringMap.empty;
     MidLint.importedScheme := (fn g => SOME (ToMid.globalScheme g) handle Error.Bug _ => NONE))

  fun binderOf (key : string) : string = case StringMap.find (!binders, key) of SOME i => i | NONE => ""

  fun register (u : loaded) =
    (units := u :: !units;
     byIdentity := StringMap.insert (!byIdentity, #identity u, u);
     List.app (fn k => if Vector.sub (#count u, k) = 0 then ()
                       else Array.update (ranges, k, addRange (Array.sub (ranges, k),
                                                               (Vector.sub (#base u, k), Vector.sub (#count u, k), u))))
              [kStamp, kTycon, kTvar])

  (* ---- fingerprints (the incremental roadmap's M6, the third part) ---- *)

  (* The fixity the unit at hand begins with, beside its environment
     (Env.session): what a usage of an identifier's fixity is checked
     against *)
  val sessionFixity : Fixity.env ref = ref Fixity.initial
  val () = CompilerState.cellRoot ("UnitBasis.sessionFixity", sessionFixity)

  (* and the signatures and functors it begins with: a usage of one is its
     fingerprint there, as a usage of a value is its fingerprint in
     Env.session, though the unit declares another of the name before its
     usages are worked out (functors-units, F1) *)
  val sessionSigs : SigMatch.sigma StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("UnitBasis.sessionSigs", sessionSigs)
  val sessionFuns : Elaborate.funinfo StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("UnitBasis.sessionFuns", sessionFuns)

  (* The place of the unit about to be looked for in the cache or compiled:
     its environment and fixity, which usages are checked against *)
  fun position (env : Env.env, fixity : Fixity.env) : unit =
    (Env.session := SOME env; sessionFixity := fixity; sessionSigs := !Elaborate.sigs; sessionFuns := !Elaborate.funs)

  (* The path that reaches each name of a loaded unit in what it declared,
     by kind and stamp: the first, in the order of the names *)
  val paths : string IntTable.table vector = Vector.tabulate (3, fn _ => IntTable.table 64)
  val () = CompilerState.tableVectorRoot ("UnitBasis.paths", paths)
  (* and the other way: by a loaded unit's identity, the name of each kind that
     a path reaches in it, by kind and path *)
  val byPath : int StringMap.map StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("UnitBasis.byPath", byPath)
  fun pathKey (k : int, p : string) = Int.toString k ^ "\000" ^ p
  fun walkPaths (delta : Env.env, sigs : (string * SigMatch.sigma) list, put : int * int * string -> unit) : unit =
    let
      fun walk (prefix, Env.Env {vals, tys, strs,...}) =
        (StringMap.appi (fn (n, v) =>
                           case v of
                             Env.Val {stamp, ...} => put (kStamp, stamp, prefix ^ n)
                           | Env.Exn {info, ...} => put (kStamp, #stamp info, prefix ^ n)
                           | Env.ExnAsVal {info, ...} => put (kStamp, #stamp info, prefix ^ n)
                           | _ => ()) vals;
         StringMap.appi (fn (n, Env.TyStr {fcn, ...}) =>
                           case fcn of T.TName c => put (kTycon, #stamp c, prefix ^ n) | _ => ()) tys;
         StringMap.appi (fn (n, e) => walk (prefix ^ n ^ ".", e)) strs)
    in
      walk ("", delta);
      (* a signature's specifications, which a unit that matched or applied
         it names, by sig:NAME and the path in it *)
      List.app (fn (n, sg : SigMatch.sigma) => walk ("sig:" ^ n ^ ".", #env sg)) sigs
    end
  fun notePaths (u : loaded, delta : Env.env, sigs : (string * SigMatch.sigma) list) : unit =
    let
      fun own (k, s) = s >= Vector.sub (#base u, k) andalso s < Vector.sub (#base u, k) + Vector.sub (#count u, k)
      val reached = ref StringMap.empty
      fun put (k, s, p) =
        if not (own (k, s)) then ()
        else
          (reached := StringMap.insert (!reached, pathKey (k, p), s);
           if isSome (IntTable.find (Vector.sub (paths, k), s)) then () else IntTable.insert (Vector.sub (paths, k), s, p))
    in
      walkPaths (delta, sigs, put);
      byPath := StringMap.insert (!byPath, #identity u, !reached);
      (* and the signatures themselves, where a fingerprint finds the
         structure a specification's stamp is in (fpChild) *)
      List.app (fn (n, sg) => unitSigs := StringMap.insert (!unitSigs, #identity u ^ "\000" ^ n, sg)) sigs
    end
  (* the same paths, of the type names of a unit not loaded: by each the path
     notePaths would give it, which an entry names a type by while its
     identity moves (the compiler library's analysis) *)
  fun typePaths (delta : Env.env, sigs : (string * SigMatch.sigma) list) : string IntTable.table =
    let
      val found = IntTable.table 64
      fun put (k, s, p) =
        if k <> kTycon orelse isSome (IntTable.find (found, s)) then () else IntTable.insert (found, s, p)
    in walkPaths (delta, sigs, put); found end

  (* What the cache keeps of a unit by its identity, for a unit compiled
     against it to be loaded against another of the same name (remapping):
     the path to each of its own names of each kind, by its number there *)
  fun pathsOf (u : loaded) : (int * int * string) list =
    List.concat
      (List.map (fn k =>
                   List.mapPartial (fn i => Option.map (fn p => (k, i, p))
                                                       (IntTable.find (Vector.sub (paths, k), Vector.sub (#base u, k) + i)))
                                   (List.tabulate (Vector.sub (#count u, k), fn i => i)))
                [kStamp, kTycon])

  (* A name, the same from session to session: built in, or its unit's name
     and the path to it there -- its place among the unit's own where no
     path reaches it, which may move as the unit changes *)
  fun anchor (k : int, s : int) : string =
    if s < Vector.sub (!builtin, k) then "b" ^ Int.toString s
    else
      case rangeOf (k, s) of
        SOME (b, u) =>
          #name u ^ ":" ^ (case IntTable.find (Vector.sub (paths, k), s) of
                             SOME p => p
                           | NONE => "#" ^ Int.toString (s - b))
      | NONE => "?" ^ Int.toString s
  (* a type name's anchor, where it is built in or a loaded unit's *)
  fun typeAnchor (s : int) : string option =
    if s < Vector.sub (!builtin, kTycon) orelse isSome (rangeOf (kTycon, s)) then SOME (anchor (kTycon, s)) else NONE

  (* what a type name is, by stamp, once worked out: its anchor and what
     defines it, so that a change of the definition shows in every
     fingerprint that names it *)
  val tyconFps : string IntTable.table = IntTable.table 64
  val () = CompilerState.tableRoot ("UnitBasis.tyconFps", tyconFps)
  (* whether a value's fingerprint names the value (not for a signature's
     ABI: sigFingerprint) *)
  val anchorValues = ref true
  val () = CompilerState.cellRoot ("UnitBasis.anchorValues", anchorValues)

  (* What --pass-stats=hash counts, beside the bytes each place hashes
     (Pickle.counted): the part of a unit's compile that hashes them, which
     labels them, and the hits and misses of fpMemo by that part *)
  val phase = ref "other"
  val () = CompilerState.cellRoot ("UnitBasis.phase", phase)
  val memoCounts : (string * int * int) list ref = ref []     (* phase, hits, misses *)
  val () = CompilerState.cellRoot ("UnitBasis.memoCounts", memoCounts)
  fun countMemo (hit : bool) : unit =
    if !P.counting then
      let
        val l = !phase
        val (h, m) = if hit then (1, 0) else (0, 1)
        fun add [] = [(l, h, m)]
          | add ((k, a, b) :: rest) = if k = l then (k, a + h, b + m) :: rest else (k, a, b) :: add rest
      in memoCounts := add (!memoCounts) end
    else ()
  (* f, its hashes labelled by the phase and site *)
  fun labelled (site : string) (f : unit -> 'a) : 'a =
    if !P.counting then
      let val old = !P.label
      in P.label := !phase ^ ":" ^ site; (f () before P.label := old) handle e => (P.label := old; raise e) end
    else f ()
  fun hashAt (site : string, text : string) : string = labelled site (fn () => P.hash text)
  (* the part of a compile f is, for the counts *)
  fun during (ph : string) (f : unit -> 'a) : 'a =
    let val old = !phase
    in phase := ph; (f () before phase := old) handle e => (phase := old; raise e) end

  (* --pass-stats=hash: what was hashed, by phase and site, and the memo's
     hits and misses, so far in the process *)
  fun hashStats () : unit =
    if !P.counting then
      (List.app (fn (l, b, c) => TextIO.output (TextIO.stdErr, "hash " ^ l ^ ": " ^ Int.toString b ^ " bytes, "
                                                            ^ Int.toString c ^ " hashes\n")) (!P.counted);
       List.app (fn (l, h, m) => TextIO.output (TextIO.stdErr, "memo " ^ l ^ ": " ^ Int.toString h ^ " hits, "
                                                            ^ Int.toString m ^ " misses\n")) (!memoCounts))
    else ()

  (* ---- what a fingerprint is of (functors-units, S1 and S2) ----

     A fingerprint is the hash of tokens, not of text: a tag for each kind of
     node, a length before each list and string, and numbers as Pickle
     writes them, so that no two things give one sequence of tokens. The
     data is written as it is: a type variable with its equality (issue 16),
     a type abbreviation's parameters, a signature's own type names by their
     place among its bound and generated names with their arity and
     equality, constructors' tags, opaque types' realisations, the "known"
     and "prim" facts of values, values' anchors (but in a signature's ABI
     and a functor's signature), and an environment in the order of its
     names. A structure's, a signature's and a functor's fingerprint is the
     hash of their entries' names and fingerprints (S1): no text is longer
     than an entry's, and an entry of a structure a usage names is worked
     out once, by its binder and its key, as the usage of it would be
     (fpMemo). A type name's fingerprint is its anchor and the hash of the
     strongly connected group of type names its definition is in, each named
     inside the group by its anchor: one value for a recursive group,
     whichever of it is asked for first (as GHC hashes them since its
     #18733; E5 of functors-units found the spurious misses the order made). *)

  (* the type names worked out in this fingerprint that are not kept: the
     unit's own, whose stamps are given again after it is loaded *)
  val scratch : string IntTable.table ref = ref (IntTable.table 16)
  val () = CompilerState.refRoot ("UnitBasis.scratch", scratch, IntTable.copy)
  (* the group of type names whose definitions are being written, by stamp *)
  val members : unit IntMap.map ref = ref IntMap.empty
  val () = CompilerState.cellRoot ("UnitBasis.members", members)

  (* A fingerprint of the static layer alone (docs/units.md, Layers): what
     elaboration reads of a name, without what a client's code is built on:
     no value's anchor or facts, no realisation of an opaque type. A compile's
     key is the whole of it, a compile being a reader of both layers; a
     compile that makes no code reads this one, and analysis and batch
     give the same. *)
  val staticLayer = ref false
  val () = CompilerState.cellRoot ("UnitBasis.staticLayer", staticLayer)

  (* f under the static layer, or as it is *)
  fun inStatic (f : unit -> 'a) : 'a =
    let
      val () = (staticLayer := true; scratch := IntTable.table 16)
      val x = f () handle e => (staticLayer := false; raise e)
    in staticLayer := false; x end

  fun knownTycon (s : int) : string option =
    if !staticLayer then
      (case IntTable.find (!staticTycons, s) of
         SOME f => SOME f
       | NONE => IntTable.find (!scratch, s))
    else
      case IntTable.find (tyconFps, s) of
        SOME f => SOME f
      | NONE => IntTable.find (!scratch, s)

  fun hashed (site : string) (f : P.writer -> unit) : string = let val w = P.writer () in f w; hashAt (site, P.contents w) end

  (* the type names a type names, but a signature's own (local) *)
  fun tyconsOf (local' : int IntMap.map, t : T.ty, acc : T.tycon list) : T.tycon list =
    case T.prune t of
      T.TVar _ => acc
    | T.TCon (c, args) =>
        List.foldl (fn (a, acc) => tyconsOf (local', a, acc)) (if IntMap.member (local', #stamp c) then acc else c :: acc) args
    | T.TRecord fs => List.foldl (fn ((_, a), acc) => tyconsOf (local', a, acc)) acc fs
    | T.TArrow (a, b) => tyconsOf (local', b, tyconsOf (local', a, acc))

  fun schemeOf (v : Env.valstatus) : T.ty =
    case v of
      Env.Val {scheme, ...} => scheme
    | Env.Con {scheme, ...} => scheme
    | Env.Exn {ty, ...} => ty
    | Env.Prim {scheme, ...} => scheme
    | Env.ConAsVal {scheme, ...} => scheme
    | Env.ExnAsVal {ty, ...} => ty

  (* the type names a type name's definition names: its constructors' types
     and its realisation *)
  fun definitionNames (local' : int IntMap.map, s : int) : T.tycon list =
    let
      val fromCons = case IntMap.find (!Elaborate.dataCons, s) of
                       SOME cs => List.foldl (fn ((_, v), acc) => tyconsOf (local', schemeOf v, acc)) [] cs
                     | NONE => []
    in
      if !staticLayer then fromCons else
      case IntTable.find (Ty.realizations, s) of
        SOME (T.TName c) => if IntMap.member (local', #stamp c) then fromCons else c :: fromCons
      | SOME (T.TAbbrev (_, body)) => tyconsOf (local', body, fromCons)
      | NONE => fromCons
    end

  (* How the constructors of a datatype of these constructors lie, by tag: the
     fields of one laid out flat (Ty.elabLayout, from the elaborator's own
     types), which a parameter's open constructor must fit
     (Elaborate.descriptors). The one fact of a layout elaboration reads, so
     the static layer's, in the realised types' terms *)
  fun layoutOf (s : int, cs : (string * Env.valstatus) list) : (int * int option) list =
    case IntMap.find (!Ty.pinned, s) of
      SOME l => l
    | NONE =>
        let
          fun shape (tag, scheme) =
            (tag, case T.prune scheme of T.TArrow (a, _) => Ty.shapeOf a | _ => NONE)
          val all = List.mapPartial (fn (_, Env.Con {scheme, info}) => SOME (shape (#tag info, scheme))
                                      | (_, Env.ConAsVal {scheme, info}) => SOME (shape (#tag info, scheme))
                                      | _ => NONE) cs
          fun insert (x as (t, _), []) = [x]
            | insert (x as (t, _), (y as (u, _)) :: rest) = if t < u then x :: y :: rest else y :: insert (x, rest)
        in List.foldl insert [] all end

  (* of a type: its generic variables numbered by first occurrence (tvs) *)
  fun fpTy (w : P.writer, tvs : int list ref, local' : int IntMap.map, t : T.ty) : unit =
    case T.prune t of
      T.TVar (ref (T.Unbound {id, eq, ...})) =>
        let
          fun index (_, []) = NONE
            | index (i, x :: rest) = if x = id then SOME i else index (i + 1, rest)
        in
          (* an equality variable is another type: ''a -> int is not
             'a -> int (docs/plans/build-cache-issues.md, issue 16) *)
          P.byte (w, if eq then 2 else 1);
          case index (0, !tvs) of
            SOME i => P.nat (w, i)
          | NONE => (tvs := !tvs @ [id]; P.nat (w, List.length (!tvs) - 1))
        end
    | T.TVar _ => P.byte (w, 3)
    | T.TCon (c, args) =>
        (P.byte (w, 4); fpTyconRef (w, local', c); P.nat (w, List.length args); List.app (fn a => fpTy (w, tvs, local', a)) args)
    | T.TRecord fs =>
        (P.byte (w, 5); P.nat (w, List.length fs); List.app (fn (l, a) => (P.string (w, l); fpTy (w, tvs, local', a))) fs)
    | T.TArrow (a, b) => (P.byte (w, 6); fpTy (w, tvs, local', a); fpTy (w, tvs, local', b))

  (* a type name: a signature's own by its place, one of the group being
     written by its anchor, any other by its fingerprint *)
  and fpTyconRef (w : P.writer, local' : int IntMap.map, c : T.tycon) : unit =
    case IntMap.find (local', #stamp c) of
      SOME i => (P.byte (w, 10); P.nat (w, i))
    | NONE =>
        if IntMap.member (!members, #stamp c) then (P.byte (w, 12); P.string (w, anchor (kTycon, #stamp c)))
        else (P.byte (w, 11); P.string (w, fpTycon (local', c)))

  and fpTycon (local', c : T.tycon) : string =
    case knownTycon (#stamp c) of
      SOME f => f
    | NONE => (groups (local', c);
               case knownTycon (#stamp c) of SOME f => f | NONE => bug "a type name its group did not fingerprint")

  (* Tarjan's strongly connected components of the type names reachable
     from c that are not fingerprinted yet, each fingerprinted as it is
     completed: the groups it names are done before it *)
  and groups (local', root : T.tycon) : unit =
    let
      val index : int IntTable.table = IntTable.table 16
      val low : int IntTable.table = IntTable.table 16
      val stack : T.tycon list ref = ref []
      val counter = ref 0
      fun lowOf s = valOf (IntTable.find (low, s))
      fun visit (c : T.tycon) : unit =
        let
          val s = #stamp c
          val i = !counter
          val () = (counter := i + 1; IntTable.insert (index, s, i); IntTable.insert (low, s, i); stack := c :: !stack)
          fun edge (d : T.tycon) =
            let val t = #stamp d
            in
              if isSome (knownTycon t) then ()
              else
                case IntTable.find (index, t) of
                  (* visited, not done: on the stack *)
                  SOME ti => IntTable.insert (low, s, Int.min (lowOf s, ti))
                | NONE => (visit d; IntTable.insert (low, s, Int.min (lowOf s, lowOf t)))
            end
          val () = List.app edge (definitionNames (local', s))
          fun pop acc =
            case !stack of
              d :: rest => (stack := rest; if #stamp d = s then d :: acc else pop (d :: acc))
            | [] => bug "Tarjan's stack ran out"
        in
          if lowOf s = i then group (local', pop []) else ()
        end
    in visit root end

  (* a group of type names: each by its anchor, in their order, and its
     definition; each one's fingerprint its anchor and the group's hash *)
  and group (local', cs : T.tycon list) : unit =
    let
      fun insert (x as (a, _), []) = [x]
        | insert (x as (a, _), (y as (b, _)) :: rest) = if a < b then x :: y :: rest else y :: insert (x, rest)
      val named = List.foldl insert [] (List.map (fn c => (anchor (kTycon, #stamp c), c)) cs)
      val outer = !members
      val () = members := List.foldl (fn (c, m) => IntMap.insert (m, #stamp c, ())) outer cs
      val g = hashed "tycon"
                (fn w => (P.nat (w, List.length named);
                          List.app (fn (a, c) => (P.string (w, a); definition (w, local', c))) named))
              handle e => (members := outer; raise e)
      val () = members := outer
      fun keep s = isSome (rangeOf (kTycon, s)) orelse s < Vector.sub (!builtin, kTycon)
    in
      List.app (fn (a, c) => IntTable.insert (if not (keep (#stamp c)) then !scratch
                                              else if !staticLayer then !staticTycons else tyconFps,
                                              #stamp c, a ^ "#" ^ g)) named
    end

  and definition (w : P.writer, local', c : T.tycon) : unit =
    let val s = #stamp c
    in
      P.nat (w, #arity c); P.bool (w, #eq c);
      definitionBody (w, local', s)
    end

  (* the constructors, how they lie, and the realisation *)
  and definitionBody (w : P.writer, local', s : int) : unit =
    ((case IntMap.find (!Elaborate.dataCons, s) of
        SOME cs => (P.nat (w, List.length cs); List.app (fn (n, v) => (P.string (w, n); fpVal (w, local', v))) cs;
                    fpLayout (w, layoutOf (s, cs)))
      | NONE => P.nat (w, 0));
     if !staticLayer then P.byte (w, 0)
     else
       case IntTable.find (Ty.realizations, s) of
         SOME f => (P.byte (w, 1); fpFcn (w, local', f))
       | NONE => P.byte (w, 0))

  and fpLayout (w : P.writer, l : (int * int option) list) : unit =
    (P.nat (w, List.length l); List.app (fn (t, n) => (P.nat (w, t); P.option P.nat (w, n))) l)

  and fpFcn (w : P.writer, local' : int IntMap.map, f : T.tyfcn) : unit =
    case f of
      T.TName c => (P.byte (w, 13); fpTyconRef (w, local', c))
    | T.TAbbrev (params, body) => (P.byte (w, 14); P.nat (w, List.length params); fpTy (w, ref params, local', body))

  and fpVal (w : P.writer, local' : int IntMap.map, v : Env.valstatus) : unit =
    let
      fun ty t = fpTy (w, ref [], local', t)
      (* which value: another with the same type is another value -- but
         for a signature's ABI and a functor's signature, whose values are
         specifications *)
      fun anchored stamp = P.string (w, if !anchorValues andalso not (!staticLayer) then anchor (kStamp, stamp) else "")
    in
      case v of
        Env.Val {scheme, stamp, ...} =>
          if !staticLayer then (P.byte (w, 20); ty scheme) else
          (P.byte (w, 20); anchored stamp; ty scheme;
           (case IntMap.find (!Translate.primAliases, stamp) of
              SOME p => (P.byte (w, 1); P.string (w, p))
            | NONE => P.byte (w, 0));
           P.bool (w, IntMap.member (!Lower.knownBefore, stamp));
           (* the global it is (Expand.globalAliases), which a use of it
              is, and what that one is to a call *)
           if !anchorValues then
             ((case IntTable.find (!Expand.globalAliases, stamp) of
                 SOME h =>
                   (P.byte (w, 1); P.string (w, anchor (kStamp, h));
                    P.option P.string (w, IntMap.find (!Translate.primAliases, h));
                    P.option P.string (w, IntTable.find (!Expand.primGlobals, h));
                    P.bool (w, IntMap.member (!Lower.knownBefore, h)))
               | NONE => P.byte (w, 0));
              P.option P.string (w, IntTable.find (!Expand.primGlobals, stamp)))
           else ())
      | Env.Con {scheme, info} => (P.byte (w, 21); P.string (w, #name info); P.int (w, #tag info); ty scheme)
      | Env.Exn {ty = t, info} => (P.byte (w, 22); anchored (#stamp info); ty t)
      | Env.Prim {scheme, name} => (P.byte (w, 23); P.string (w, name); ty scheme)
      | Env.ConAsVal {scheme, info} => (P.byte (w, 24); P.string (w, #name info); P.int (w, #tag info); ty scheme)
      | Env.ExnAsVal {ty = t, info} => (P.byte (w, 25); anchored (#stamp info); ty t)
    end

  (* a type name known by its stamp alone, as a type of the IRs names one: what
     defines it, with no arity or equality, which only its record has *)
  fun fpStampOnly (s : int) : string =
    hashed "tycon" (fn w =>
      (P.string (w, anchor (kTycon, s)); definitionBody (w, IntMap.empty, s)))

  fun fpTyStr (w : P.writer, local' : int IntMap.map, Env.TyStr {fcn, cons}) : unit =
    (fpFcn (w, local', fcn); P.nat (w, List.length cons); List.app (fn (n, v) => (P.string (w, n); fpVal (w, local', v))) cons)

  (* a usage's fingerprint by its binder and key, from fpMemo, or worked out
     by f and kept *)
  fun memo (binder : string, key : string, f : unit -> string option) : string option =
    let val m = (if !staticLayer then "S\000" else "") ^ binder ^ "\000" ^ key
    in
      case StringMap.find (!fpMemo, m) of
        SOME r => (countMemo true; r)
      | NONE => let val () = countMemo false val r = f () in fpMemo := StringMap.insert (!fpMemo, m, r); r end
    end

  fun localsOf (cs : T.tycon list) : int IntMap.map =
    #2 (List.foldl (fn (c, (i, m)) => (i + 1, IntMap.insert (m, #stamp c, i))) (0, IntMap.empty) cs)

  (* ---- structures by reference (functors-units M11, part 1; E12) ----

     A usage's stream of a signature or a functor wrote every structure of
     its environment whole, nested signatures and all: the signatures of
     MLton's build hashed 512 MB, almost all of it the same structures again
     (E12). In such a stream (childRefs), a structure the environment holds
     -- a child -- that is a structure of a loaded signature, realised, is
     written as a reference to it: that structure's fingerprint, worked out
     once a session (refMemo), and the realisation, what each of its own
     type names is in the child. The structure is found by the path its
     first value's stamp has in the unit that declared the signature
     (sig:NAME.a.b.v, notePaths): a specification's stamp is kept by
     instantiation, realisation and the bases. A walk of both checks that
     the child is the structure realised, and derives the realisation
     (realisation). A functor's result, whose values are the summary's
     placeholders, is looked up by the names of its entries among the
     structures its parameter's children were found to be, and checked the
     same way. Where none is found or the walk fails, the child is written
     whole, its own children each tried in turn.

     A reference tells apart all that the child's tokens did: the
     structure's tokens, each of its own type names written as the
     realisation's image of it, are the child's -- the walk checks that each
     entry is there under the same name, a value with the same stamp (in a
     functor's stream, where no anchor is written, with none of a stamp's
     facts on either side), a type with the same names but the
     structure's own, each of those its image every time (a type name, or a
     type without variables for one without parameters), and each type
     variable in the same places with the same equality. Where it is not,
     nothing is assumed. *)
  val childRefs = ref false
  val () = CompilerState.cellRoot ("UnitBasis.childRefs", childRefs)
  (* in a functor's stream: whether the parameter or the result is being
     written, and the structures the parameter's children were found to be,
     with each of theirs, by the names of their entries *)
  val inParam = ref false
  val () = CompilerState.cellRoot ("UnitBasis.inParam", inParam)
  val inResult = ref false
  val () = CompilerState.cellRoot ("UnitBasis.inResult", inResult)
  val paramRefs : (string * int IntMap.map * Env.env) list StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("UnitBasis.paramRefs", paramRefs)

  exception NoMatch

  (* the local names an environment names, by stamp, in the order of their
     first occurrence: its values', then its types', then its structures' *)
  fun localOrder (local' : int IntMap.map, en : Env.env) : int list =
    let
      val seen : unit IntMap.map ref = ref IntMap.empty
      val order : int list ref = ref []
      fun tc (c : T.tycon) =
        let val s = #stamp c
        in if IntMap.member (local', s) andalso not (IntMap.member (!seen, s))
           then (seen := IntMap.insert (!seen, s, ()); order := s :: !order) else () end
      fun ty t =
        case T.prune t of
          T.TVar _ => ()
        | T.TCon (c, args) => (tc c; List.app ty args)
        | T.TRecord fs => List.app (fn (_, a) => ty a) fs
        | T.TArrow (a, b) => (ty a; ty b)
      fun fcn f = case f of T.TName c => tc c | T.TAbbrev (_, b) => ty b
      fun walk (Env.Env {vals, tys, strs, ...}) =
        (StringMap.app (fn v => ty (schemeOf v)) vals;
         StringMap.app (fn (Env.TyStr {fcn = f, cons}) => (fcn f; List.app (fn (_, v) => ty (schemeOf v)) cons)) tys;
         StringMap.app walk strs)
    in walk en; List.rev (!order) end

  (* a value's stamp, where it has one of its own *)
  fun valueStamp (v : Env.valstatus) : int option =
    case v of
      Env.Val {stamp, ...} => SOME stamp
    | Env.Exn {info, ...} => if isSome (#builtin info) then NONE else SOME (#stamp info)
    | Env.ExnAsVal {info, ...} => if isSome (#builtin info) then NONE else SOME (#stamp info)
    | _ => NONE

  (* a loaded signature's own type names, by its unit and name ("ID\000NAME"),
     and a structure's of a loaded signature in their order, by its key
     ("ID\000NAME\000PATH"): each worked out once a session *)
  fun sigLocalsOf (key : string, sg : SigMatch.sigma) : int IntMap.map =
    case StringMap.find (!sigLocals, key) of
      SOME m => m
    | NONE => let val m = localsOf (#bound sg) in sigLocals := StringMap.insert (!sigLocals, key, m); m end
  fun orderOf (key : string, cl : int IntMap.map, c : Env.env) : int list =
    case StringMap.find (!targetOrders, key) of
      SOME l => l
    | NONE => let val l = localOrder (cl, c) in targetOrders := StringMap.insert (!targetOrders, key, l); l end

  (* the first value of en's tree with a stamp, and the path from en to the
     structure that holds it *)
  fun firstStamp (Env.Env {vals, strs, ...}) : (string list * int) option =
    let
      val stamped = valueStamp
    in
      case StringMap.foldli (fn (_, v, NONE) => stamped v | (_, _, found) => found) NONE vals of
        SOME s => SOME ([], s)
      | NONE => StringMap.foldli (fn (n, e, NONE) => Option.map (fn (q, s) => (n :: q, s)) (firstStamp e)
                                   | (_, _, found) => found) NONE strs
    end

  (* the path of the structure a structure at path strPath of a signature
     is, where a value at path q in it is at strPath there *)
  fun stripPath (q : string list, strPath : string list) : string list option =
    let val nq = List.length q val np = List.length strPath
    in if nq > np orelse List.drop (strPath, np - nq) <> q then NONE else SOME (List.take (strPath, np - nq)) end

  (* the structure of a loaded signature that a value with stamp s at path
     q of a structure may say the structure is: the unit, the signature's
     name and itself, the path, and the structure *)
  fun candidateAt (q : string list, s : int) : (loaded * string * SigMatch.sigma * string list * Env.env) option =
    case (IntTable.find (Vector.sub (paths, kStamp), s), rangeOf (kStamp, s)) of
      (SOME p, SOME (_, u)) =>
        if not (String.isPrefix "sig:" p) then NONE
        else
          (case String.fields (fn c => c = #".") (String.extract (p, 4, NONE)) of
             name :: (rest as _ :: _) =>
               (case (stripPath (q, List.take (rest, List.length rest - 1)), StringMap.find (!unitSigs, #identity u ^ "\000" ^ name)) of
                  (SOME cpath, SOME (sg : SigMatch.sigma)) =>
                    Option.map (fn c => (u, name, sg, cpath, c)) (Env.findStr' (#env sg, cpath))
                | _ => NONE)
           | _ => NONE)
    | _ => NONE

  (* the structure of a loaded signature en may be, by its first value's
     stamp: its key (unit, signature, path), the signature's own type
     names, and the structure *)
  fun candidate (en : Env.env) : (string * int IntMap.map * Env.env) option =
    case firstStamp en of
      NONE => NONE
    | SOME (q, s) =>
        Option.map (fn (u, name, sg, cpath, c) =>
                      (#identity u ^ "\000" ^ name ^ "\000" ^ String.concatWith "." cpath,
                       sigLocalsOf (#identity u ^ "\000" ^ name, sg), c))
                   (candidateAt (q, s))

  (* the realisation by which en is c, a structure whose own type names are
     cl, by their stamps; NoMatch where it is not (the checks above). bare:
     a value's stamp may differ where neither has a fact a stream writes *)
  fun realisation (cl : int IntMap.map, c : Env.env, en : Env.env, bare : bool) : T.tyfcn IntMap.map =
    let
      val phi : T.tyfcn IntMap.map ref = ref IntMap.empty
      val fromTyStr : unit IntMap.map ref = ref IntMap.empty
      fun isLocal (k : T.tycon) = IntMap.member (cl, #stamp k)
      fun factless (s : int) = not (IntMap.member (!Translate.primAliases, s)) andalso not (IntMap.member (!Lower.knownBefore, s))
      fun sameStamp (a : int, b : int) = a = b orelse !staticLayer orelse (bare andalso factless a andalso factless b)
      fun tvPair (tv : (int * int) list ref) (a : int, e1 : bool, b : int, e2 : bool) : unit =
        if e1 <> e2 then raise NoMatch
        else
          case List.find (fn (x, _) => x = a) (!tv) of
            SOME (_, y) => if y = b then () else raise NoMatch
          | NONE => if List.exists (fn (_, y) => y = b) (!tv) then raise NoMatch else tv := (a, b) :: !tv
      fun noTvars (t : T.ty) : unit =
        case T.prune t of
          T.TVar _ => raise NoMatch
        | T.TCon (_, args) => List.app noTvars args
        | T.TRecord fs => List.app (fn (_, a) => noTvars a) fs
        | T.TArrow (a, b) => (noTvars a; noTvars b)
      (* two types of en, the same where type variables are in the same places *)
      fun plain (tv : (int * int) list ref) (t1 : T.ty, t2 : T.ty) : unit =
        case (T.prune t1, T.prune t2) of
          (T.TVar (ref (T.Unbound {id = a, eq = e1, ...})), T.TVar (ref (T.Unbound {id = b, eq = e2, ...}))) => tvPair tv (a, e1, b, e2)
        | (T.TCon (k1, a1), T.TCon (k2, a2)) =>
            if #stamp k1 = #stamp k2 andalso List.length a1 = List.length a2 then ListPair.app (plain tv) (a1, a2) else raise NoMatch
        | (T.TRecord f1, T.TRecord f2) =>
            if List.length f1 = List.length f2
            then ListPair.app (fn ((l1, x), (l2, y)) => if l1 = l2 then plain tv (x, y) else raise NoMatch) (f1, f2)
            else raise NoMatch
        | (T.TArrow (a1, b1), T.TArrow (a2, b2)) => (plain tv (a1, a2); plain tv (b1, b2))
        | _ => raise NoMatch
      (* a type of c and one of en: the second the first realised *)
      fun ty (tv : (int * int) list ref) (t1 : T.ty, t2 : T.ty) : unit =
        case (T.prune t1, T.prune t2) of
          (T.TVar (ref (T.Unbound {id = a, eq = e1, ...})), T.TVar (ref (T.Unbound {id = b, eq = e2, ...}))) => tvPair tv (a, e1, b, e2)
        | (T.TCon (k, args1), t2') =>
            if isLocal k then
              (case IntMap.find (!phi, #stamp k) of
                 NONE =>
                   if List.null args1 then (noTvars t2'; phi := IntMap.insert (!phi, #stamp k, T.TAbbrev ([], t2')))
                   else
                     (case t2' of
                        T.TCon (k2, args2) =>
                          if List.length args2 = List.length args1
                          then (phi := IntMap.insert (!phi, #stamp k, T.TName k2); ListPair.app (ty tv) (args1, args2))
                          else raise NoMatch
                      | _ => raise NoMatch)
               | SOME (T.TName k2) =>
                   (case t2' of
                      T.TCon (k3, args2) =>
                        if #stamp k3 = #stamp k2 andalso List.length args1 = List.length args2
                        then ListPair.app (ty tv) (args1, args2) else raise NoMatch
                    | _ => raise NoMatch)
               | SOME (T.TAbbrev ([], b)) => if List.null args1 then plain (ref []) (b, t2') else raise NoMatch
               | SOME _ => raise NoMatch)
            else
              (case t2' of
                 T.TCon (k2, args2) =>
                   if #stamp k2 = #stamp k andalso List.length args1 = List.length args2
                   then ListPair.app (ty tv) (args1, args2) else raise NoMatch
               | _ => raise NoMatch)
        | (T.TRecord f1, T.TRecord f2) =>
            if List.length f1 = List.length f2
            then ListPair.app (fn ((l1, x), (l2, y)) => if l1 = l2 then ty tv (x, y) else raise NoMatch) (f1, f2)
            else raise NoMatch
        | (T.TArrow (a1, b1), T.TArrow (a2, b2)) => (ty tv (a1, a2); ty tv (b1, b2))
        | _ => raise NoMatch
      fun fcnPlain (f1 : T.tyfcn, f2 : T.tyfcn) : unit =
        case (f1, f2) of
          (T.TName a, T.TName b) => if #stamp a = #stamp b then () else raise NoMatch
        | (T.TAbbrev (p1, b1), T.TAbbrev (p2, b2)) =>
            if List.length p1 = List.length p2 then plain (ref (ListPair.zip (p1, p2))) (b1, b2) else raise NoMatch
        | _ => raise NoMatch
      (* g, an image a type gave, and f2, the one a type's specification gives *)
      fun fcnFromTy (g : T.tyfcn, f2 : T.tyfcn) : unit =
        case (g, f2) of
          (T.TAbbrev ([], t), T.TName k2) => plain (ref []) (t, T.TCon (k2, []))
        | (T.TAbbrev ([], t), T.TAbbrev ([], b)) => plain (ref []) (t, b)
        | (T.TName a, T.TName b) => if #stamp a = #stamp b then () else raise NoMatch
        | _ => raise NoMatch
      fun value (v1 : Env.valstatus, v2 : Env.valstatus) : unit =
        case (v1, v2) of
          (Env.Val {scheme = s1, stamp = a, ...}, Env.Val {scheme = s2, stamp = b, ...}) =>
            if sameStamp (a, b) then ty (ref []) (s1, s2) else raise NoMatch
        | (Env.Con {scheme = s1, info = i1}, Env.Con {scheme = s2, info = i2}) =>
            if #name i1 = #name i2 andalso #tag i1 = #tag i2 then ty (ref []) (s1, s2) else raise NoMatch
        | (Env.Exn {ty = t1, info = i1}, Env.Exn {ty = t2, info = i2}) =>
            if sameStamp (#stamp i1, #stamp i2) then ty (ref []) (t1, t2) else raise NoMatch
        | (Env.Prim {scheme = s1, name = n1}, Env.Prim {scheme = s2, name = n2}) =>
            if n1 = n2 then ty (ref []) (s1, s2) else raise NoMatch
        | (Env.ConAsVal {scheme = s1, info = i1}, Env.ConAsVal {scheme = s2, info = i2}) =>
            if #name i1 = #name i2 andalso #tag i1 = #tag i2 then ty (ref []) (s1, s2) else raise NoMatch
        | (Env.ExnAsVal {ty = t1, info = i1}, Env.ExnAsVal {ty = t2, info = i2}) =>
            if sameStamp (#stamp i1, #stamp i2) then ty (ref []) (t1, t2) else raise NoMatch
        | _ => raise NoMatch
      fun tyStr (Env.TyStr {fcn = f1, cons = c1}, Env.TyStr {fcn = f2, cons = c2}) : unit =
        ((case f1 of
            T.TName k =>
              if isLocal k then
                (case IntMap.find (!phi, #stamp k) of
                   NONE => (phi := IntMap.insert (!phi, #stamp k, f2); fromTyStr := IntMap.insert (!fromTyStr, #stamp k, ()))
                 | SOME g =>
                     if IntMap.member (!fromTyStr, #stamp k) then fcnPlain (g, f2)
                     else (fcnFromTy (g, f2); phi := IntMap.insert (!phi, #stamp k, f2);
                           fromTyStr := IntMap.insert (!fromTyStr, #stamp k, ())))
              else (case f2 of T.TName k2 => if #stamp k2 = #stamp k then () else raise NoMatch | _ => raise NoMatch)
          | T.TAbbrev (p1, b1) =>
              (case f2 of
                 T.TAbbrev (p2, b2) =>
                   if List.length p1 = List.length p2 then ty (ref (ListPair.zip (p1, p2))) (b1, b2) else raise NoMatch
               | _ => raise NoMatch));
         if List.length c1 = List.length c2
         then ListPair.app (fn ((n1, v1), (n2, v2)) => if n1 = n2 then value (v1, v2) else raise NoMatch) (c1, c2)
         else raise NoMatch)
      fun keysEq (m1 : 'a StringMap.map, m2 : 'b StringMap.map) : bool =
        StringMap.numItems m1 = StringMap.numItems m2
        andalso StringMap.foldli (fn (n, _, ok) => ok andalso isSome (StringMap.find (m2, n))) true m1
      fun env (Env.Env {vals = v1, tys = t1, strs = s1, ...}, Env.Env {vals = v2, tys = t2, strs = s2, ...}) : unit =
        if not (keysEq (v1, v2) andalso keysEq (t1, t2) andalso keysEq (s1, s2)) then raise NoMatch
        else
          (StringMap.appi (fn (n, x) => tyStr (x, valOf (StringMap.find (t2, n)))) t1;
           StringMap.appi (fn (n, x) => value (x, valOf (StringMap.find (v2, n)))) v1;
           StringMap.appi (fn (n, x) => env (x, valOf (StringMap.find (s2, n)))) s1)
    in env (c, en); !phi end

  (* The realisation by which en is c renamed, as a basis's reference must
     have it (functors-units M11, part 2): what reading c's names again
     makes of it is en. Stricter than realisation: the same type variables
     (cells), the same type names (stamp, name, arity, equality) but c's
     own, each of those the same image wherever it is; the same
     constructors and exceptions but their stamps and whether they are
     global, and a type's constructors only constructors. The
     stamps and the flags of en's values, and c's, in the order of the
     values (by name, then each structure's in turn); NoMatch where en is
     not c renamed. *)
  type renaming = {phi : T.tyfcn IntMap.map, stamps : int list, globals : bool list, cStamps : int list, cGlobals : bool list}
  fun renaming (cl : int IntMap.map, c : Env.env, en : Env.env) : renaming =
    let
      val phi : T.tyfcn IntMap.map ref = ref IntMap.empty
      val fromTyStr : unit IntMap.map ref = ref IntMap.empty
      val stamps : int list ref = ref []
      val globals : bool list ref = ref []
      val cStamps : int list ref = ref []
      val cGlobals : bool list ref = ref []
      fun isLocal (k : T.tycon) = IntMap.member (cl, #stamp k)
      fun sameTycon (a : T.tycon, b : T.tycon) =
        #stamp a = #stamp b andalso #arity a = #arity b andalso #eq a = #eq b andalso #name a = #name b
      fun noTvars (t : T.ty) : unit =
        case T.prune t of
          T.TVar _ => raise NoMatch
        | T.TCon (_, args) => List.app noTvars args
        | T.TRecord fs => List.app (fn (_, a) => noTvars a) fs
        | T.TArrow (a, b) => (noTvars a; noTvars b)
      fun plain (t1 : T.ty, t2 : T.ty) : unit =
        case (T.prune t1, T.prune t2) of
          (T.TVar r1, T.TVar r2) => if r1 = r2 then () else raise NoMatch
        | (T.TCon (k1, a1), T.TCon (k2, a2)) =>
            if sameTycon (k1, k2) andalso List.length a1 = List.length a2 then ListPair.app plain (a1, a2) else raise NoMatch
        | (T.TRecord f1, T.TRecord f2) =>
            if List.length f1 = List.length f2
            then ListPair.app (fn ((l1, x), (l2, y)) => if l1 = l2 then plain (x, y) else raise NoMatch) (f1, f2)
            else raise NoMatch
        | (T.TArrow (a1, b1), T.TArrow (a2, b2)) => (plain (a1, a2); plain (b1, b2))
        | _ => raise NoMatch
      fun ty (t1 : T.ty, t2 : T.ty) : unit =
        case (T.prune t1, T.prune t2) of
          (T.TVar r1, T.TVar r2) => if r1 = r2 then () else raise NoMatch
        | (T.TCon (k, args1), t2') =>
            if isLocal k then
              (case IntMap.find (!phi, #stamp k) of
                 NONE =>
                   if List.null args1 then (noTvars t2'; phi := IntMap.insert (!phi, #stamp k, T.TAbbrev ([], t2')))
                   else
                     (case t2' of
                        T.TCon (k2, args2) =>
                          if List.length args2 = List.length args1 andalso #arity k2 = #arity k
                          then (phi := IntMap.insert (!phi, #stamp k, T.TName k2); ListPair.app ty (args1, args2))
                          else raise NoMatch
                      | _ => raise NoMatch)
               | SOME (T.TName k2) =>
                   (case t2' of
                      T.TCon (k3, args2) =>
                        if sameTycon (k3, k2) andalso List.length args1 = List.length args2 then ListPair.app ty (args1, args2)
                        else raise NoMatch
                    | _ => raise NoMatch)
               | SOME (T.TAbbrev ([], b)) => if List.null args1 then plain (b, t2') else raise NoMatch
               | SOME _ => raise NoMatch)
            else
              (case t2' of
                 T.TCon (k2, args2) =>
                   if sameTycon (k, k2) andalso List.length args1 = List.length args2 then ListPair.app ty (args1, args2)
                   else raise NoMatch
               | _ => raise NoMatch)
        | (T.TRecord f1, T.TRecord f2) =>
            if List.length f1 = List.length f2
            then ListPair.app (fn ((l1, x), (l2, y)) => if l1 = l2 then ty (x, y) else raise NoMatch) (f1, f2)
            else raise NoMatch
        | (T.TArrow (a1, b1), T.TArrow (a2, b2)) => (ty (a1, a2); ty (b1, b2))
        | _ => raise NoMatch
      fun fcnPlain (f1 : T.tyfcn, f2 : T.tyfcn) : unit =
        case (f1, f2) of
          (T.TName a, T.TName b) => if sameTycon (a, b) then () else raise NoMatch
        | (T.TAbbrev (p1, b1), T.TAbbrev (p2, b2)) => if p1 = p2 then plain (b1, b2) else raise NoMatch
        | _ => raise NoMatch
      fun fcnFromTy (g : T.tyfcn, f2 : T.tyfcn) : unit =
        case (g, f2) of
          (T.TAbbrev ([], t), T.TName k2) => plain (t, T.TCon (k2, []))
        | (T.TAbbrev ([], t), T.TAbbrev ([], b)) => plain (t, b)
        | (T.TName a, T.TName b) => if sameTycon (a, b) then () else raise NoMatch
        | _ => raise NoMatch
      fun exn (i1 : Ast.exninfo, i2 : Ast.exninfo) : unit =
        if #name i1 = #name i2 andalso #hasArg i1 = #hasArg i2 andalso #builtin i1 = #builtin i2
        then (stamps := #stamp i2 :: !stamps; globals := #isGlobal i2 :: !globals;
              cStamps := #stamp i1 :: !cStamps; cGlobals := #isGlobal i1 :: !cGlobals)
        else raise NoMatch
      fun value (v1 : Env.valstatus, v2 : Env.valstatus) : unit =
        case (v1, v2) of
          (Env.Val {scheme = s1, stamp = a, global = g1}, Env.Val {scheme = s2, stamp = b, global = g2}) =>
            (ty (s1, s2); stamps := b :: !stamps; globals := g2 :: !globals; cStamps := a :: !cStamps; cGlobals := g1 :: !cGlobals)
        | (Env.Con {scheme = s1, info = i1}, Env.Con {scheme = s2, info = i2}) => if i1 = i2 then ty (s1, s2) else raise NoMatch
        | (Env.Exn {ty = t1, info = i1}, Env.Exn {ty = t2, info = i2}) => (ty (t1, t2); exn (i1, i2))
        | (Env.Prim {scheme = s1, name = n1}, Env.Prim {scheme = s2, name = n2}) => if n1 = n2 then ty (s1, s2) else raise NoMatch
        | (Env.ConAsVal {scheme = s1, info = i1}, Env.ConAsVal {scheme = s2, info = i2}) =>
            if i1 = i2 then ty (s1, s2) else raise NoMatch
        | (Env.ExnAsVal {ty = t1, info = i1}, Env.ExnAsVal {ty = t2, info = i2}) => (ty (t1, t2); exn (i1, i2))
        | _ => raise NoMatch
      (* a type's constructors: constructors alone, which have no stamps *)
      fun con (v1 : Env.valstatus, v2 : Env.valstatus) : unit =
        case (v1, v2) of
          (Env.Con _, Env.Con _) => value (v1, v2)
        | (Env.ConAsVal _, Env.ConAsVal _) => value (v1, v2)
        | _ => raise NoMatch
      fun tyStr (Env.TyStr {fcn = f1, cons = c1}, Env.TyStr {fcn = f2, cons = c2}) : unit =
        ((case f1 of
            T.TName k =>
              if isLocal k then
                (case IntMap.find (!phi, #stamp k) of
                   NONE => (phi := IntMap.insert (!phi, #stamp k, f2); fromTyStr := IntMap.insert (!fromTyStr, #stamp k, ()))
                 | SOME g =>
                     if IntMap.member (!fromTyStr, #stamp k) then fcnPlain (g, f2)
                     else (fcnFromTy (g, f2); phi := IntMap.insert (!phi, #stamp k, f2);
                           fromTyStr := IntMap.insert (!fromTyStr, #stamp k, ())))
              else (case f2 of T.TName k2 => if sameTycon (k, k2) then () else raise NoMatch | _ => raise NoMatch)
          | T.TAbbrev (p1, b1) =>
              (case f2 of T.TAbbrev (p2, b2) => if p1 = p2 then ty (b1, b2) else raise NoMatch | _ => raise NoMatch));
         if List.length c1 = List.length c2
         then ListPair.app (fn ((n1, v1), (n2, v2)) => if n1 = n2 then con (v1, v2) else raise NoMatch) (c1, c2)
         else raise NoMatch)
      fun keysEq (m1 : 'a StringMap.map, m2 : 'b StringMap.map) : bool =
        StringMap.numItems m1 = StringMap.numItems m2
        andalso StringMap.foldli (fn (n, _, ok) => ok andalso isSome (StringMap.find (m2, n))) true m1
      fun env (Env.Env {vals = v1, tys = t1, strs = s1, ...}, Env.Env {vals = v2, tys = t2, strs = s2, ...}) : unit =
        if not (keysEq (v1, v2) andalso keysEq (t1, t2) andalso keysEq (s1, s2))
        then raise NoMatch
        else
          (StringMap.appi (fn (n, x) => tyStr (x, valOf (StringMap.find (t2, n)))) t1;
           StringMap.appi (fn (n, x) => value (x, valOf (StringMap.find (v2, n)))) v1;
           StringMap.appi (fn (n, x) => env (x, valOf (StringMap.find (s2, n)))) s1)
    in
      env (c, en);
      {phi = !phi, stamps = List.rev (!stamps), globals = List.rev (!globals),
       cStamps = List.rev (!cStamps), cGlobals = List.rev (!cGlobals)}
    end

  (* A structure's template, which each reference to it is made from (a
     load reads it in the time of the structure's distinct types, not of
     their occurrences, and shares them as a basis read whole shares the
     types it wrote once, issue 14): its types, each once -- by what it is
     made of, its parts' numbers before it -- whether each names one of the
     structure's own type names, and the number of the type at each place a
     type is, in the order renamedEnv takes them (values by name, then
     types, each its definition's body and its constructors, then each
     structure in turn) *)

  (* the types an environment has, in the order a template numbers them *)
  fun envTypes (f : T.ty -> unit) (Env.Env {vals, tys, strs, ...}) : unit =
    (List.app (fn (_, v) => f (schemeOf v)) (StringMap.listItemsi vals);
     List.app (fn (_, Env.TyStr {fcn, cons}) =>
                 ((case fcn of T.TAbbrev (_, b) => f b | T.TName _ => ());
                  List.app (fn (_, v) => f (schemeOf v)) cons)) (StringMap.listItemsi tys);
     List.app (fn (_, e) => envTypes f e) (StringMap.listItemsi strs))

  fun makeTemplate (cl : int IntMap.map, c : Env.env) : template =
    let
      val table : (int list * string list * int) list IntTable.table = IntTable.table 1024
      val nodes : tnode list ref = ref []
      val origs : T.ty list ref = ref []
      val owns : bool list ref = ref []
      val count = ref 0
      val ownedSoFar : bool IntTable.table = IntTable.table 1024
      fun owned i = getOpt (IntTable.find (ownedSoFar, i), false)
      fun fresh (node : tnode, orig : T.ty, own : bool) : int =
        let val i = !count
        in count := i + 1; nodes := node :: !nodes; origs := orig :: !origs; owns := own :: !owns;
           IntTable.insert (ownedSoFar, i, own); i end
      fun add (ints : int list, labels : string list, node : tnode, orig : T.ty, own : bool) : int =
        let
          val h = List.foldl (fn (x, h) => (h * 31 + x mod 1000003) mod 1000003) (List.length labels) ints
          val bucket = getOpt (IntTable.find (table, h), [])
        in
          case List.find (fn (is, ls, _) => is = ints andalso ls = labels) bucket of
            SOME (_, _, i) => i
          | NONE => let val i = fresh (node, orig, own) in IntTable.insert (table, h, (ints, labels, i) :: bucket); i end
        end
      fun intern (t : T.ty) : int =
        case T.prune t of
          t' as T.TVar (r as ref (T.Unbound {id, ...})) =>
            (* by its id where it is the variable of that id the session has *)
            (case IntTable.find (!tvars, id) of
               SOME cell => if cell = r then add ([0, id], [], NVar, t', false) else fresh (NVar, t', false)
             | NONE => fresh (NVar, t', false))
        | t' as T.TVar _ => fresh (NVar, t', false)
        | t' as T.TCon (k, args) =>
            let val ks = List.map intern args
            in add ([1, #stamp k, #arity k, if #eq k then 1 else 0] @ ks, [#name k], NCon (k, ks), t',
                    IntMap.member (cl, #stamp k) orelse List.exists owned ks)
            end
        | t' as T.TRecord fs =>
            let val ks = List.map (fn (_, a) => intern a) fs
            in add (2 :: ks, List.map #1 fs, NRec (ListPair.zip (List.map #1 fs, ks)), t', List.exists owned ks) end
        | t' as T.TArrow (a, b) =>
            let val ka = intern a val kb = intern b
            in add ([3, ka, kb], [], NArr (ka, kb), t', owned ka orelse owned kb) end
      val slots : int list ref = ref []
      val () = envTypes (fn t => slots := intern t :: !slots) c
    in
      {nodes = Vector.fromList (List.rev (!nodes)), orig = Vector.fromList (List.rev (!origs)),
       owned = Vector.fromList (List.rev (!owns)), slots = Vector.fromList (List.rev (!slots))}
    end

  (* each type of a template realised by phi, where it names one of the
     structure's own type names, and else the type itself *)
  fun instantiate (tp : template, phi : T.tyfcn IntMap.map) : T.ty vector =
    let
      val n = Vector.length (#nodes tp)
      val res : T.ty array = Array.array (n, T.TRecord [])
      fun r i = Array.sub (res, i)
      fun one i =
        let val orig = Vector.sub (#orig tp, i)
        in
          if not (Vector.sub (#owned tp, i)) then orig
          else
            case Vector.sub (#nodes tp, i) of
              NVar => orig
            | NCon (k, ks) =>
                (case IntMap.find (phi, #stamp k) of
                   NONE => T.TCon (k, List.map r ks)
                 | SOME (T.TName k2) => T.TCon (k2, List.map r ks)
                 | SOME (T.TAbbrev ([], b)) => if List.null ks then b else T.realize (phi, orig)
                 | SOME _ => T.realize (phi, orig))
            | NRec fs => T.TRecord (List.map (fn (l, j) => (l, r j)) fs)
            | NArr (a, b) => T.TArrow (r a, r b)
        end
      fun loop i = if i >= n then () else (Array.update (res, i, one i); loop (i + 1))
    in loop 0; Array.vector res end

  fun templateOf (key : string, cl : int IntMap.map, c : Env.env) : template =
    case StringMap.find (!templates, key) of
      SOME tp => tp
    | NONE => let val tp = makeTemplate (cl, c) in templates := StringMap.insert (!templates, key, tp); tp end

  (* c renamed: what a basis's reference reads as (renaming) -- its types
     those of instantiate, in the order its template numbers its places;
     its own type names in a type's definition by phi; its values' stamps
     and flags from the lists where they are given (in the order renaming
     gives them) *)
  fun renamedEnv (tp : template, phi : T.tyfcn IntMap.map, stamps : int list ref option, globals : bool list ref option)
                 (c : Env.env) : Env.env =
    let
      val types = instantiate (tp, phi)
      val pos = ref 0
      fun ty (_ : T.ty) : T.ty =
        let val i = !pos
        in
          if i >= Vector.length (#slots tp) then raise Pickle.Bad "a reference's template ran out"
          else (pos := i + 1; Vector.sub (types, Vector.sub (#slots tp, i)))
        end
      fun next (l : 'a list ref option, old : 'a) : 'a =
        case l of
          NONE => old
        | SOME r => (case !r of x :: rest => (r := rest; x) | [] => raise Pickle.Bad "a reference's names ran out")
      fun exn (info : Ast.exninfo) : Ast.exninfo =
        let val s = next (stamps, #stamp info) val g = next (globals, #isGlobal info)
        in {name = #name info, stamp = s, isGlobal = g, hasArg = #hasArg info, builtin = #builtin info} end
      fun value (v : Env.valstatus) : Env.valstatus =
        case v of
          Env.Val {scheme, stamp, global} =>
            let val t = ty scheme val s = next (stamps, stamp) val g = next (globals, global)
            in Env.Val {scheme = t, stamp = s, global = g} end
        | Env.Con {scheme, info} => Env.Con {scheme = ty scheme, info = info}
        | Env.Exn {ty = t, info} => let val t' = ty t in Env.Exn {ty = t', info = exn info} end
        | Env.Prim {scheme, name} => Env.Prim {scheme = ty scheme, name = name}
        | Env.ConAsVal {scheme, info} => Env.ConAsVal {scheme = ty scheme, info = info}
        | Env.ExnAsVal {ty = t, info} => let val t' = ty t in Env.ExnAsVal {ty = t', info = exn info} end
      fun tystr (Env.TyStr {fcn, cons}) : Env.tystatus =
        let
          val fcn' = case fcn of
                       T.TName k => (case IntMap.find (phi, #stamp k) of SOME g => g | NONE => fcn)
                     | T.TAbbrev (ids, body) => T.TAbbrev (ids, ty body)
          val cons' = List.map (fn (n, v) => (n, value v)) cons
        in Env.TyStr {fcn = fcn', cons = cons'} end
      fun go (Env.Env {vals, tys, strs, origins}) : Env.env =
        let
          val vals' = List.foldl (fn ((n, v), m) => StringMap.insert (m, n, value v)) StringMap.empty (StringMap.listItemsi vals)
          val tys' = List.foldl (fn ((n, t), m) => StringMap.insert (m, n, tystr t)) StringMap.empty (StringMap.listItemsi tys)
          val strs' = List.foldl (fn ((n, e), m) => StringMap.insert (m, n, go e)) StringMap.empty (StringMap.listItemsi strs)
        in Env.Env {vals = vals', tys = tys', strs = strs', origins = origins} end
      val en = go c
    in
      if !pos = Vector.length (#slots tp) then en else raise Pickle.Bad "a reference's template left over"
    end

  (* the names of an environment's entries, by which a functor's result is
     looked up among the structures of its parameter *)
  fun namesKey (Env.Env {vals, tys, strs, ...}) : string =
    String.concatWith " " (StringMap.foldri (fn (n, _, acc) => n :: acc) [] vals) ^ "\000"
    ^ String.concatWith " " (StringMap.foldri (fn (n, _, acc) => n :: acc) [] tys) ^ "\000"
    ^ String.concatWith " " (StringMap.foldri (fn (n, _, acc) => n :: acc) [] strs)

  (* a structure of a signature, and each of its own, kept by the names of
     its entries for a functor's result (paramRefs) *)
  fun noteParam (key : string, cl : int IntMap.map, c : Env.env) : unit =
    let
      val k = namesKey c
      val l = getOpt (StringMap.find (!paramRefs, k), [])
    in
      if List.exists (fn (key', _, _) => key' = key) l then ()
      else paramRefs := StringMap.insert (!paramRefs, k, l @ [(key, cl, c)]);
      StringMap.appi (fn (n, sub) => noteParam (key ^ (if String.isSuffix "\000" key then "" else ".") ^ n, cl, sub)) (Env.strs c)
    end

  (* An environment written whole, its values, types and structures each
     kind in the order of the names, each entry by its name and what it is:
     a signature's and a functor's, whose entries no usage names; each
     structure by reference where it may be (fpChild) *)
  fun fpEnvInto (w : P.writer, local' : int IntMap.map, Env.Env {vals, tys, strs, ...}) : unit =
    (P.nat (w, StringMap.numItems vals); StringMap.appi (fn (n, v) => (P.string (w, n); fpVal (w, local', v))) vals;
     P.nat (w, StringMap.numItems tys); StringMap.appi (fn (n, t) => (P.string (w, n); fpTyStr (w, local', t))) tys;
     P.nat (w, StringMap.numItems strs); StringMap.appi (fn (n, e) => (P.string (w, n); fpChild (w, local', e))) strs)

  (* a child: whole as before but in a usage's stream, and there a byte, 0
     and the child whole, or 1 and a reference -- the structure's
     fingerprint and the image of each of its own type names in the order
     of their first occurrence in it *)
  and fpChild (w : P.writer, local' : int IntMap.map, en : Env.env) : unit =
    if not (!childRefs) then fpEnvInto (w, local', en)
    else
      case reference en of
        SOME (fp, order, phi) =>
          (P.byte (w, 1); P.string (w, fp); P.nat (w, List.length order);
           List.app (fn s => fpFcn (w, local', valOf (IntMap.find (phi, s)))) order)
      | NONE => (P.byte (w, 0); fpEnvInto (w, local', en))

  (* the reference that may stand for en: the structure's fingerprint, its
     own type names, and the realisation *)
  and reference (en : Env.env) : (string * int list * T.tyfcn IntMap.map) option =
    let
      fun check (key, cl, c) =
        let
          val order = orderOf (key, cl, c)
          val phi = realisation (cl, c, en, not (!anchorValues))
        in
          if List.all (fn s => IntMap.member (phi, s)) order then SOME (structureFp (key, cl, c, order), order, phi) else NONE
        end
        handle NoMatch => NONE
    in
      case candidate en of
        SOME (x as (key, cl, c)) =>
          (case check x of
             SOME r => (if !inParam then noteParam (key, cl, c) else (); SOME r)
           | NONE => NONE)
      | NONE =>
          if not (!inResult) then NONE
          else
            let
              fun try [] = NONE
                | try (x :: rest) = (case check x of SOME r => SOME r | NONE => try rest)
            in try (getOpt (StringMap.find (!paramRefs, namesKey en), [])) end
    end

  (* a signature's structure's fingerprint: its tokens, its own type names
     numbered in the order of their first occurrence in it, worked out once
     a session, apart from any functor's stream *)
  and structureFp (key : string, cl : int IntMap.map, c : Env.env, order : int list) : string =
    let val m = (if !staticLayer then "S" else "") ^ (if !anchorValues then "v\000" else "-\000") ^ key
    in
      case StringMap.find (!refMemo, m) of
        SOME f => f
      | NONE =>
          let
            val own = #2 (List.foldl (fn (s, (i, m)) => (i + 1, IntMap.insert (m, s, i))) (0, IntMap.empty) order)
            val saved = (!inParam, !inResult)
            val () = (inParam := false; inResult := false)
            val f = hashed "sigref" (fn w => fpEnvInto (w, own, c))
                    handle e => (inParam := #1 saved; inResult := #2 saved; raise e)
          in
            inParam := #1 saved; inResult := #2 saved;
            refMemo := StringMap.insert (!refMemo, m, f); f
          end
    end

  (* A structure's fingerprint, of one a usage names: its entries of each
     kind in the order of their names, each by its name and fingerprint,
     which is the usage of its long name's (S1): binder bound the
     structure, and prefix ^ name is an entry's long name (memo) *)
  fun fpEnv ((binder, prefix) : string * string, Env.Env {vals, tys, strs, ...}) : string =
    let
      val w = P.writer ()
      fun child (kind : string, n : string, f : unit -> string) : string =
        case memo (binder, kind ^ " " ^ prefix ^ n, fn () => SOME (f ())) of SOME d => d | NONE => ""
      fun entries (kind : string, m : 'a StringMap.map, f : string * 'a -> unit -> string) =
        (P.nat (w, StringMap.numItems m); StringMap.appi (fn (n, x) => (P.string (w, n); P.string (w, child (kind, n, f (n, x))))) m)
    in
      entries ("v", vals, fn (_, v) => fn () => hashed "v" (fn w => fpVal (w, IntMap.empty, v)));
      entries ("t", tys, fn (_, t) => fn () => hashed "t" (fn w => fpTyStr (w, IntMap.empty, t)));
      entries ("s", strs, fn (n, e) => fn () => fpEnv ((binder, prefix ^ n ^ "."), e));
      hashAt ("env", P.contents w)
    end

  (* a signature's or a functor's own type names: how many, and of each its
     arity and whether it admits equality (issue 16) *)
  fun fpBound (w : P.writer, cs : T.tycon list) : unit =
    (P.nat (w, List.length cs); List.app (fn c => (P.nat (w, #arity c); P.bool (w, #eq c))) cs)

  fun fpSigma ({bound, env = en, ...} : SigMatch.sigma) : string =
    hashed "sig" (fn w => (fpBound (w, bound); fpEnvInto (w, localsOf bound, en)))

  (* the fingerprint of a signature's ABI (a dynamic module's: Elaborate,
     StrDynamic and StrExport): what its specifications say, the types they
     name by their units' names and paths, and nothing of where the
     signature was written *)
  (* A program compiled whole -- by a whole-program compile, or of its units'
     Mid -- loads no module and is none, and its _export's fingerprint is a
     constant, the same both ways (Main sets wholeFingerprints) *)
  val wholeFingerprints = ref false
  val () = CompilerState.cellRoot ("UnitBasis.wholeFingerprints", wholeFingerprints)
  val () = Elaborate.sigFingerprint :=
             (* a usage too: a unit made with one is not the other's *)
             (fn sg => if (Usage.use ("whole", "on"); !wholeFingerprints) then "whole"
                       else
                         let val () = (anchorValues := false; scratch := IntTable.table 16)
                             (* the ABI's form too: a structure's record with
                                its substructures' records nested (D3), so that
                                a module made for the flat records before is
                                refused, not misread *)
                             val f = labelled "sigabi" (fn () => hashAt ("sigabi", "nested records\000" ^ fpSigma sg))
                                     handle e => (anchorValues := true; raise e)
                         in anchorValues := true; f end)

  (* The fingerprint of a virtual or dynamic functor's ABI (the build-system
     roadmap's D22; Elaborate, functor F = _virtual (X : A) : B and _export
     functor): the ABI's version, its calling convention and its records'
     slots, as Elaborate gives them (Elaborate.functorShape), then A and B,
     their own type names by their places among both lists -- B names A's
     where the result's types are the parameter's (where type key = K.t)
     -- and every other type name by its unit's name and path, with what
     defines it, as the ABI layer's fingerprints have it (a realisation
     too): nothing of where the signatures were written, and nothing of an
     implementation. Pickle.hash gives every host the same (D22) *)
  val () = Elaborate.functorFingerprint :=
             (fn (param : SigMatch.sigma, result : SigMatch.sigma, shape : string) =>
                if (Usage.use ("whole", "on"); !wholeFingerprints) then "whole"
                else
                  let
                    val () = (anchorValues := false; scratch := IntTable.table 16)
                    val local' = localsOf (#bound param @ #bound result)
                    val f = labelled "funabi"
                              (fn () => hashed "funabi"
                                          (fn w => (P.string (w, shape);
                                                    fpBound (w, #bound param); fpEnvInto (w, local', #env param);
                                                    fpBound (w, #bound result); fpEnvInto (w, local', #env result))))
                            handle e => (anchorValues := true; raise e)
                  in anchorValues := true; f end)

  (* of a functor: its signature, the parameter's own type names and those
     its body made local to it, its values specifications *)
  fun fpFunctor (Elaborate.FunInfo {paramSig = {bound, env = pe,...}, summary = {generated, result}, ...}) : string option =
    let
      val local' = localsOf (bound @ generated)
      fun reset () = (anchorValues := true; inParam := false; inResult := false; paramRefs := StringMap.empty)
      val () = (anchorValues := false; paramRefs := StringMap.empty)
      val f = hashed "fun" (fn w => (fpBound (w, bound);
                                     inParam := true; fpEnvInto (w, local', pe); inParam := false;
                                     fpBound (w, generated);
                                     inResult := true; fpEnvInto (w, local', result); inResult := false))
              handle e => (reset (); raise e)
    in reset (); SOME f end

  (* What the REPL decided a declaration's echo by when it compiled it
     (src/repl): whether it echoed at all (the usage "echo on") and whether
     a printer was installed for a type (the usage "p KEY", KEY its stable
     name). Neither is a name a unit binds, and both shape the code of a
     declaration of a file used, which the cache keeps: a usage of either
     holds where the REPL decides the same now
     (docs/plans/build-cache-issues.md, issue 3). Off outside the REPL. *)
  val replSetting : (string -> bool) ref = ref (fn _ => false)
  val () = CompilerState.cellRoot ("UnitBasis.replSetting", replSetting)

  (* The unit that bound a usage's name: of a long name, its first
     structure's; of a setting of the REPL's, "on" where it is on *)
  fun binderOfKey (key : string) : string =
    if String.isPrefix "p " key orelse String.isPrefix "echo " key then (if !replSetting key then "on" else "")
    else if key = "whole on" then (if !wholeFingerprints then "on" else "")
    (* a functor inlined where it is applied: the unit that bound it, and
       its Mid's hash where that unit is another *)
    else if String.isPrefix "inl " key then binderOf ("fun " ^ String.extract (key, 4, NONE))
    (* a function inlined where it is named: the unit that bound the name,
       as of the value's usage (functors-units M10) *)
    else if String.isPrefix "inlv " key then binderOfKey ("v " ^ String.extract (key, 5, NONE))
    else
    case String.fields (fn c => c = #" ") key of
      [kind, name] =>
        if kind <> "v" andalso kind <> "t" then binderOf key
        else
          (case String.fields (fn c => c = #".") name of
             first :: _ :: _ => binderOf ("s " ^ first)
           | _ => binderOf key)
    | _ => binderOf key

  (* The fingerprint of what a usage names in the session as it is now:
     NONE where nothing does. A functor is its signature (fpFunctor), and a
     functor inlined where it is applied its function's Mid too ("inl").
     An overloading is its binder's identity: what it is is the whole
     unit's. *)
  (* a usage's stream, its structures by reference where they may be (fpChild) *)
  fun byReference (f : unit -> 'a) : 'a =
    (childRefs := true; (f () before childRefs := false) handle e => (childRefs := false; raise e))

  fun fingerprint (key : string) : string option =
    let
      val (kind, name) = case String.fields (fn c => c = #" ") key of k :: rest => (k, String.concatWith " " rest) | [] => ("", "")
      val path = String.fields (fn c => c = #".") name
      val (strs, last) = (List.take (path, List.length path - 1), List.last path)
      val env = case !Env.session of SOME e => e | NONE => Env.initial
      fun inStr f = case Env.findStr' (env, strs) of SOME e => f e | NONE => NONE
      val () = scratch := IntTable.table 16
    in
      case kind of
        "v" => inStr (fn e => Option.map (fn v => hashed "v" (fn w => fpVal (w, IntMap.empty, v))) (StringMap.find (Env.vals e, last)))
      | "t" => inStr (fn e => Option.map (fn t => hashed "t" (fn w => fpTyStr (w, IntMap.empty, t))) (StringMap.find (Env.tys e, last)))
      | "s" => Option.map (fn e => fpEnv ((binderOfKey key, name ^ "."), e)) (Env.findStr' (env, path))
      | "sig" => Option.map (fn sg => byReference (fn () => fpSigma sg)) (StringMap.find (!sessionSigs, name))
      | "fun" => (case StringMap.find (!sessionFuns, name) of SOME f => byReference (fn () => fpFunctor f) | NONE => NONE)
      | "inl" => (case StringMap.find (!sessionFuns, name) of
                    SOME (Elaborate.FunInfo {code = g, ...}) => inlineHash g
                  | _ => NONE)
      (* a function inlined where it is named: its Mid's hash, through the
         globals that are it (functors-units M10) *)
      | "inlv" => inStr (fn e => case StringMap.find (Env.vals e, last) of
                                   SOME (Env.Val {stamp, ...}) => Option.mapPartial inlineHash (Expand.inlinedValue stamp)
                                 | _ => NONE)
      | "fix" => SOME (hashAt ("fix", case StringMap.find (#table (!sessionFixity), name) of
                                        NONE => "nonfix"
                                      | SOME Fixity.Nonfix => "nonfix"
                                      | SOME (Fixity.Infix p) => "infix " ^ Int.toString p
                                      | SOME (Fixity.Infixr p) => "infixr " ^ Int.toString p))
      | _ => NONE
    end

  (* A usage holds as "IDENTITY FINGERPRINT": the binder's identity, which
     settles it where it is the same, and the fingerprint of what the name
     names, which settles the rest (a name no fingerprint covers -- a
     functor, an overloading, a fixity -- by its binder alone) *)
  (* a usage's fingerprint by its key and binder, once worked out: what a
     name names is its binder's entry by that name, the same in every unit
     that names it there (fingerprints are a third of a compile in units
     where each unit works out its own) *)
  fun fingerprintAt (key : string, binder : string) : string option = memo (binder, key, fn () => fingerprint key)

  fun usageValue (key : string) : string =
    let val b = binderOfKey key
    in b ^ " " ^ (case fingerprintAt (key, b) of SOME f => f | NONE => "-") end

  (* The usages of a compile: each name it looked up (Usage) *)
  fun usagesOf (names : string list) : (string * string) list = during "usages" (fn () => List.map (fn k => (k, usageValue k)) names)

  (* a unit's name, from its identity, name@hash *)
  fun nameOfIdentity (identity : string) : string =
    case List.rev (String.fields (fn c => c = #"@") identity) of
      _ :: (rest as _ :: _) => String.concatWith "@" (List.rev rest)
    | _ => identity

  (* the first usage that does not hold in the session as it is, if one.
     By its fingerprint only where the unit that bound the name is not in
     the session: the entry's code names that unit's globals, which a unit
     loaded in its place takes over (remapping), while a unit of the
     session keeps them -- where the REPL used a file again, or another
     unit binds the name now, the code would reach the old unit's *)
  fun broken (us : (string * string) list) : string option = during "find" (fn () =>
    let
      fun holds (k, v) =
        let
          (* "IDENTITY FINGERPRINT", an identity a name that may have spaces in it *)
          val fs = String.fields (fn c => c = #" ") v
          val fp = List.last fs
          val i = String.concatWith " " (List.take (fs, List.length fs - 1))
          val b = binderOfKey k
        in
          b = i orelse (fp <> "-" andalso not (isSome (StringMap.find (!byIdentity, i))) andalso fingerprintAt (k, b) = SOME fp)
        end
    in Option.map #1 (List.find (not o holds) us) end)

  (* whether every usage holds by its binder: an entry that needs no
     unit of the session other than those it was compiled against *)
  fun exact (us : (string * string) list) : bool =
    List.all (fn (k, v) =>
                let val fs = String.fields (fn c => c = #" ") v
                in binderOfKey k = String.concatWith " " (List.take (fs, List.length fs - 1)) end) us

  (* The first unit that the code of an entry names and the session has
     not, if one: what its usages missed (docs/plans/build-cache-issues.md,
     issue 4), which a miss compiles again rather than the link finding no
     unit to take it from *)
  fun absent (u : Link.unitCode) : string option =
    let
      fun here ({unit, ...} : Link.key) =
        unit = #unit Link.nextKey orelse unit = #identity u orelse isSome (StringMap.find (!byIdentity, unit))
    in Option.map #unit (List.find (not o here) (List.map #1 (#globals u) @ List.map #2 (#imports u))) end

  (* The schemes of the globals of other units a unit's code names -- the
     values it reads and the functions it calls -- as the session has them,
     by the unit and the number of each, in a text whose type names are
     stable from session to session (anchor): what its compile
     had, which a cache entry keeps (UnitCache), and what a compile that
     takes the entry holds the units it names now to (schemesHold). A free
     type variable of the top level is written "_", its id being the
     session's. *)
  fun schemeText (s : int) : string option =
    case IntMap.find (!schemeMemo, s) of
      SOME t => t
    | NONE => let val t = schemeTextOf s in schemeMemo := IntMap.insert (!schemeMemo, s, t); t end
  and schemeTextOf (s : int) : string option =
    (let
       val (gens, t) = ToMid.globalScheme s
       fun gen i =
         let fun go (_, []) = "?" | go (k, g :: rest) = if g = i then Int.toString k else go (k + 1, rest)
         in go (0, gens) end
       (* an anchor: not by its unit's identity, which may be another while
          what the unit that holds the scheme names of it is the same *)
       fun tycon (c, n) =
         if c < Vector.sub (!builtin, kTycon) then "b" ^ Int.toString c
         else case rangeOf (kTycon, c) of
                SOME _ => anchor (kTycon, c)
              | NONE => "?" ^ n
       (* the text's pieces, last first *)
       fun ty (t, acc) =
         case Ty.view t of
           Ty.Gen i => gen i :: "'" :: acc
         | Ty.Var _ => "_" :: acc
         | Ty.Con (c, n, []) => tycon (c, n) :: acc
         | Ty.Con (c, n, args) => ")" :: list (args, "(" :: tycon (c, n) :: acc)
         | Ty.Tuple ts => "}" :: list (ts, "{" :: acc)
         | Ty.Arrow (a, b) => ")" :: ty (b, "->" :: ty (a, "(" :: acc))
         | Ty.ExnCon => "exn" :: acc
       and list ([], acc) = acc
         | list ([t], acc) = ty (t, acc)
         | list (t :: ts, acc) = list (ts, "," :: ty (t, acc))
     in SOME (String.concat (List.rev (ty (t, [])))) end)
    handle Error.Bug _ => NONE

  fun keyText ({unit, number} : Link.key) : string = unit ^ "#" ^ Int.toString number

  (* by unit, its identity and the number and scheme of each of its globals
     the code names, in the order of the identities and the numbers *)
  fun importedSchemes (u : Link.unitCode) : (string * (int * string) list) list =
    let
      val named =
        List.foldl (fn ({unit, number} : Link.key, m) =>
                      if unit = "" orelse unit = #identity u orelse number < 0 then m
                      else StringMap.insert (m, unit, IntMap.insert (case StringMap.find (m, unit) of SOME ns => ns | NONE => IntMap.empty,
                                                                     number, ())))
                   StringMap.empty (List.map #1 (#globals u) @ List.map #2 (#imports u))
    in
      StringMap.foldri (fn (unit, ns, acc) =>
                          case StringMap.find (!byIdentity, unit) of
                            NONE => acc
                          | SOME ({base, ...} : loaded) =>
                              let val b = Vector.sub (base, kStamp)
                              in (unit, IntMap.foldri (fn (n, (), acc) =>
                                                         case schemeText (b + n) of SOME t => (n, t) :: acc | NONE => acc)
                                                      [] ns) :: acc
                              end)
                       [] named
    end

  (* the first of what an entry's compile had that the units of the session
     say otherwise of now, if one, by its key; checked where the entry holds
     by its binders, its keys naming the units it was compiled against. A
     unit not in the session is what absent says *)
  fun schemesHold (us : (string * (int * string) list) list) : string option =
    let
      fun inUnit (unit, ns) =
        case StringMap.find (!byIdentity, unit) of
          NONE => NONE
        | SOME ({base, ...} : loaded) =>
            let val b = Vector.sub (base, kStamp)
            in
              Option.map (fn (n, _) => keyText {unit = unit, number = n})
                         (List.find (fn (n, t) => case schemeText (b + n) of SOME t' => t' <> t | NONE => false) ns)
            end
      fun go [] = NONE
        | go (x :: rest) = case inUnit x of NONE => go rest | some => some
    in go us end
  (* the check where an entry is taken: SchemeChanged where one differs; a
     check of level 0, always on but where --lint=off says, which
     --pass-stats counts as "schemes" and which moves none of the
     compiler's counters (Pass.checkAt; the linting roadmap's D12) *)
  fun checkSchemes (us : (string * (int * string) list) list) : unit =
    Pass.checkAt ("schemes", 0) (fn us => Option.app (fn k => raise SchemeChanged k) (schemesHold us)) us

  (* The files a unit's code names other than file, its own, which are the
     sources of units of the session -- the bodies of the functors marked to
     be inlined that it expanded -- each with that unit's name: what a
     compile that takes the unit from the cache names them by where those
     units are then *)
  fun sourcesOf (u : Link.unitCode, file : string) : (string * string) list =
    List.mapPartial (fn f => if f = file then NONE
                             else Option.map (fn (l : loaded) => (f, #name l))
                                             (List.find (fn (l : loaded) => #file l = f) (!units)))
                    (#files (#code u))

  (* Where a file of a unit's code is now: its own, file, is name, and one
     of others the source of the unit of the session that has its name *)
  fun movedTo (file : string, name : string, others : (string * string) list) (f : string) : string =
    if f = file then name
    else
      case List.find (fn (g, _) => g = f) others of
        SOME (_, uname) => (case List.find (fn (l : loaded) => #name l = uname) (!units) of
                              SOME l => #file l
                            | NONE => f)
      | NONE => f

  (* whether a file of a unit's code from the cache is elsewhere now *)
  fun moves (u : Link.unitCode, file : string, name : string, others : (string * string) list) : bool =
    List.exists (fn f => movedTo (file, name, others) f <> f) (#files (#code u))

  (* a unit's code from the cache, its files named where they are now (S29) *)
  fun relocate (u : Link.unitCode, file : string, name : string, others : (string * string) list) : Link.unitCode =
    if moves (u, file, name, others) then UnitFile.mapFiles (u, movedTo (file, name, others)) else u

  (* ---- the state a unit begins in ---- *)

  (* What a unit's compile begins with, which its loading goes back to
     (Main, the REPL): the counters, the environment and fixity, the
     elaborator's tables, the primitives' aliases and the functions known
     by name *)
  type start = {counters : int vector, env : Env.env, fixity : Fixity.env, snapshot : Elaborate.snapshot,
                primAliases : string IntMap.map, knownBefore : unit IntMap.map}

  fun begin (env : Env.env, fixity : Fixity.env) : start =
    (Elaborate.insertedSigs := []; Elaborate.insertedFuns := []; position (env, fixity);
     {counters = counters (), env = env, fixity = fixity, snapshot = Elaborate.snapshot (),
      primAliases = !Translate.primAliases, knownBefore = !Lower.knownBefore})

  (* the tables back as the unit found them, before its basis is loaded. The
     tables by stamp only grow, and its compile filled them under the
     stamps it made, which no unit names again: its names are loaded after
     them (load, base) -- so what it bound there is taken out, which in a
     session that compiles declaration after declaration (the REPL) would
     otherwise be the type of every variable it ever compiled. *)
  fun undo (s : start) =
    let
      val now = counters ()
      fun range k = (Vector.sub (#counters s, k), Vector.sub (now, k))
      val (s0, s1) = range kStamp
      val (t0, t1) = range kTycon
      fun withoutRange m = IntMap.foldRange (fn (stamp, _, kept) => IntMap.remove (kept, stamp)) m (t0, t1) m
    in
      Elaborate.restore (#snapshot s); Translate.primAliases := #primAliases s; Lower.knownBefore := #knownBefore s;
      IntTable.removeRange (Ty.binders, s0, s1);
      IntTable.removeRange (Ty.exnArgs, s0, s1);
      IntTable.removeRange (!Expand.globalAliases, s0, s1);
      IntTable.removeRange (!Expand.primGlobals, s0, s1);
      IntTable.removeRange (!Expand.importedValues, s0, s1);
      IntTable.removeRange (!ToMid.importedSchemes, s0, s1);
      IntTable.removeRange (!inlineHashes, s0, s1);
      IntTable.removeRange (Env.stampOrigins, s0, s1);
      IntTable.removeRange (Ty.realizations, t0, t1);
      IntTable.removeRange (!staticTycons, t0, t1);
      Ty.pinned := withoutRange (!Ty.pinned);
      Ty.openTypes := withoutRange (!Ty.openTypes);
      Env.typeOrigins := withoutRange (!Env.typeOrigins)
    end

  (* A load that failed part of the way undone: what it entered in the
     tables by stamp, under the names it was given since at, taken out,
     and the counters back at at -- a remapped entry can fail in the middle
     of its basis, where a name of it has no path (rname) *)
  fun abandon (at : int vector) : unit =
    let
      val now = counters ()
      fun outside k s = s < Vector.sub (at, k) orelse s >= Vector.sub (now, k)
    in
      IntTable.removeRange (Ty.binders, Vector.sub (at, kStamp), Vector.sub (now, kStamp));
      IntTable.removeRange (Ty.exnArgs, Vector.sub (at, kStamp), Vector.sub (now, kStamp));
      IntTable.removeRange (!Expand.globalAliases, Vector.sub (at, kStamp), Vector.sub (now, kStamp));
      IntTable.removeRange (!Expand.primGlobals, Vector.sub (at, kStamp), Vector.sub (now, kStamp));
      IntTable.removeRange (!Expand.importedValues, Vector.sub (at, kStamp), Vector.sub (now, kStamp));
      IntTable.removeRange (!ToMid.importedSchemes, Vector.sub (at, kStamp), Vector.sub (now, kStamp));
      IntTable.removeRange (!inlineHashes, Vector.sub (at, kStamp), Vector.sub (now, kStamp));
      IntTable.removeRange (Ty.realizations, Vector.sub (at, kTycon), Vector.sub (now, kTycon));
      IntTable.removeRange (!staticTycons, Vector.sub (at, kTycon), Vector.sub (now, kTycon));
      Ty.datatypes := IntMap.filteri (fn (s, _) => outside kTycon s) (!Ty.datatypes);
      Ty.pinned := IntMap.filteri (fn (s, _) => outside kTycon s) (!Ty.pinned);
      Ty.openTypes := IntMap.filteri (fn (s, _) => outside kTycon s) (!Ty.openTypes);
      Env.typeOrigins := IntMap.filteri (fn (s, _) => outside kTycon s) (!Env.typeOrigins);
      Elaborate.dataCons := IntMap.filteri (fn (s, _) => outside kTycon s) (!Elaborate.dataCons);
      Translate.primAliases := IntMap.filteri (fn (s, _) => outside kStamp s) (!Translate.primAliases);
      Lower.knownBefore := IntMap.filteri (fn (s, _) => outside kStamp s) (!Lower.knownBefore);
      setCounters at
    end

  (* ---- writing ---- *)

  (* What a basis is written from that is not in the environment: the names
     of the signatures and functors the unit declared, in their order, the
     functions it declares that are copied where they are named and the
     schemes those name, a marked functor's function's body, the name of a
     function a body binds, and whether a kept body's hash is to be written
     as it was read (exportAgain) rather than worked out *)
  type writing = {sigs : string list, funs : string list, values : (int * Mid.fundef) list,
                  schemes : (int * (int list * Ty.ty)) list, body : int -> Mid.fundef option,
                  funName : int -> string option, again : bool}

  type enc = {w : P.writer,                            (* the layer being written *)
              a : P.writer,                            (* the ABI layer *)
              side : P.writer,                         (* the sidecar: origins, in the order they are met *)
              spans : bool ref,                        (* whether an origin was written at all *)
              start : int vector,
              own : int IntTable.table vector,         (* per kind: a value -> its number *)
              count : int ref vector,
              queue : (int * int) list ref,            (* own names whose tables are to be written, newest first *)
              names : int StringMap.map ref,           (* the identities named, by their place in the header *)
              nnames : int ref,                        (* how many *)
              refs : int IntTable.table,               (* the same, by the unit's range of a kind (3 * base + kind) *)
              nameList : string list ref,              (* the same, newest first *)
              imports : int IntTable.table vector,     (* per kind: another unit's name -> its place in the imports *)
              nimports : int ref vector,               (* how many *)
              importList : (int * int * int) list ref vector, (* per kind, newest first: the name, its unit's place, its number *)
              records : T.tycon IntTable.table,        (* type names of other units written, by stamp *)
              targets : (loaded * string) list ref,    (* signatures of other units referred to, newest first *)
              sigUnits : int StringMap.map ref,        (* the units of those, by their place in the static layer *)
              sigUnitList : string list ref,           (* the same, newest first *)
              tycons : int IntTable.table, ntycons : int ref,
              keys : (int list * string list * int) list IntTable.table,   (* each type's key, by what it is made of (intern) *)
              nkeys : int ref,
              types : int IntMap.map ref, ntypes : int ref,    (* the types written, by their key *)
              cons : int StringMap.map ref, ncons : int ref,   (* the constructors written, by their key *)
              sibs : int StringMap.map ref, nsibs : int ref,   (* their lists of siblings, the same *)
              funsDone : unit IntTable.table,          (* own functors written, by their functions *)
              bodies : (int * SigMatch.sigma) list ref,  (* the same with their parameters, newest first *)
              sTycons : int list ref,                  (* own type names the static layer entered, newest first *)
              stampLists : (int list * int) list IntTable.table,  (* references' stamps written, by a hash: the list, its place *)
              nstampLists : int ref,
              file : string}                           (* the unit's source, as its spans name it *)

  fun ownNumber (e : enc, k, v) : int =
    let val t = Vector.sub (#own e, k)
    in
      case IntTable.find (t, v) of
        SOME i => i
      | NONE =>
          let val c = Vector.sub (#count e, k) val i = !c
          in IntTable.insert (t, v, i); c := i + 1; #queue e := (k, v) :: !(#queue e); i end
    end

  fun unitRef (e : enc, identity : string) : int =
    case StringMap.find (!(#names e), identity) of
      SOME i => i
    | NONE =>
        let val i = !(#nnames e)
        in #names e := StringMap.insert (!(#names e), identity, i); #nnames e := i + 1; #nameList e := identity :: !(#nameList e); i end

  (* another unit's name: its place among the unit's imports, of its kind *)
  fun importOf (e : enc, k : int, v : int) : int =
    case IntTable.find (Vector.sub (#imports e, k), v) of
      SOME i => i
    | NONE =>
        case rangeOf (k, v) of
          SOME (b, u) =>
            (* the unit's place by its range, not by its identity's text,
               which a name of another unit would look up each time *)
            let
              val r = case IntTable.find (#refs e, 3 * b + k) of
                        SOME r => r
                      | NONE => let val r = unitRef (e, #identity u) in IntTable.insert (#refs e, 3 * b + k, r); r end
              val n = Vector.sub (#nimports e, k)
              val i = !n
              val l = Vector.sub (#importList e, k)
            in IntTable.insert (Vector.sub (#imports e, k), v, i); n := i + 1; l := (v, r, v - b) :: !l; i end
        | NONE => bug ("a name of no unit: kind " ^ Int.toString k ^ ", " ^ Int.toString v)

  fun nameTo (w : P.writer, e : enc, k : int, v : int) : unit =
    if v < Vector.sub (!builtin, k) then (P.byte (w, 0); P.int (w, v))
    else if v >= Vector.sub (#start e, k) then (P.byte (w, 1); P.nat (w, ownNumber (e, k, v)))
    else (P.byte (w, 2); P.nat (w, importOf (e, k, v)))

  fun name (e : enc, k : int, v : int) : unit = nameTo (#w e, e, k, v)

  (* a unit whose signature the static layer refers to, by its place among
     those: the header's list of units is in the order both layers met them,
     which a compile and an analysis meet otherwise *)
  fun sigUnit (e : enc, identity : string) : int =
    case StringMap.find (!(#sigUnits e), identity) of
      SOME i => i
    | NONE =>
        let val i = StringMap.numItems (!(#sigUnits e))
        in ignore (unitRef (e, identity)); #sigUnits e := StringMap.insert (!(#sigUnits e), identity, i);
           #sigUnitList e := identity :: !(#sigUnitList e); i end

  fun tycon (e : enc, c : T.tycon) : unit =
    let val w = #w e
    in
      case IntTable.find (#tycons e, #stamp c) of
        SOME i => (P.byte (w, 1); P.nat (w, i))
      | NONE =>
          (IntTable.insert (#tycons e, #stamp c, !(#ntycons e)); #ntycons e := !(#ntycons e) + 1;
           if #stamp c < Vector.sub (#start e, kTycon) then IntTable.insert (#records e, #stamp c, c) else ();
           P.byte (w, 0); name (e, kTycon, #stamp c); P.string (w, #name c); P.nat (w, #arity c); P.bool (w, #eq c))
    end

  fun tkind (e : enc, k : T.kind) : unit =
    let val w = #w e
    in
      case k of
        T.KPlain => P.byte (w, 0)
      | T.KRigid s => (P.byte (w, 1); P.string (w, s))
      | T.KOverload ss => (P.byte (w, 2); P.list P.string (w, ss))
      | T.KFlex _ => bug "a flexible record in a unit's basis"
    end

  (* A type is written once: after that, as the number of the first time
     (byte 4), which the reader takes for the same object. A basis names
     the same types over and over -- every value's in its environment and
     again in Ty.binders, the types of a signature's specifications -- and
     written whole each time, they were read as that many copies: a unit
     of MLton's whose signature took 3.7 MB elaborated took 15.7 MB read
     back (docs/plans/build-cache-issues.md, issue 14). The key is the
     type's structure, its names by stamp. *)
  (* A type and its parts, each with its key: a number for what it is made
     of, the same for two types alike in every part (intern), worked out
     once from the parts' keys, so that writing a type looks at each part
     once (it was the text of the whole part at each part, the square of
     the type's depth; functors-units, M4) *)
  datatype keyed = Keyed of int * T.ty * keyed list

  fun intern (e : enc, t : T.ty) : keyed =
    let
      (* what a part is made of: numbers (its kind, its name, its parts'
         keys) and labels, looked up by a number worked out from them *)
      fun keyOf (ints : int list, labels : string list, parts : keyed list) : keyed =
        let
          val ints = ints @ List.map (fn Keyed (k, _, _) => k) parts
          val h = List.foldl (fn (x, h) => (h * 31 + x mod 1000003) mod 1000003) (List.length labels) ints
          val bucket = getOpt (IntTable.find (#keys e, h), [])
          val k = case List.find (fn (is, ls, _) => is = ints andalso ls = labels) bucket of
                    SOME (_, _, k) => k
                  | NONE => let val k = !(#nkeys e)
                            in IntTable.insert (#keys e, h, (ints, labels, k) :: bucket); #nkeys e := k + 1; k end
        in Keyed (k, t, parts) end
    in
      case T.prune t of
        T.TVar (ref (T.Unbound {id, ...})) => keyOf ([0, id], [], [])
      | T.TVar _ => bug "a type pruned to a bound variable"
      | T.TCon (c, args) => keyOf ([1, #stamp c], [], List.map (fn a => intern (e, a)) args)
      | T.TRecord fs => keyOf ([2], List.map #1 fs, List.map (fn (_, a) => intern (e, a)) fs)
      | T.TArrow (a, b) => keyOf ([3], [], [intern (e, a), intern (e, b)])
    end

  fun ty (e : enc, t : T.ty) : unit = keyedTy (e, intern (e, t))
  and keyedTy (e : enc, Keyed (k, t, parts)) : unit =
    let val w = #w e
    in
      case IntMap.find (!(#types e), k) of
        SOME i => (P.byte (w, 4); P.nat (w, i))
      | NONE =>
          ((case (T.prune t, parts) of
              (T.TVar (ref (T.Unbound {id, level, kind, eq})), _) =>
                (P.byte (w, 0); name (e, kTvar, id); P.nat (w, if level = T.genericLevel then 0 else level + 1);
                 tkind (e, kind); P.bool (w, eq))
            | (T.TVar _, _) => bug "a type pruned to a bound variable"
            | (T.TCon (c, _), _) => (P.byte (w, 1); tycon (e, c); P.list (fn (_, a) => keyedTy (e, a)) (w, parts))
            | (T.TRecord fs, _) =>
                (P.byte (w, 2); P.list (fn (_, ((l, _), a)) => (P.string (w, l); keyedTy (e, a))) (w, ListPair.zip (fs, parts)))
            | (T.TArrow _, [a, b]) => (P.byte (w, 3); keyedTy (e, a); keyedTy (e, b))
            | (T.TArrow _, _) => bug "an arrow of other than two parts");
           (* numbered when it is written whole, as the reader numbers it *)
           #types e := IntMap.insert (!(#types e), k, !(#ntypes e));
           #ntypes e := !(#ntypes e) + 1)
    end

  fun tyfcn (e : enc, f : T.tyfcn) : unit =
    case f of
      T.TName c => (P.byte (#w e, 0); tycon (e, c))
    | T.TAbbrev (ids, t) => (P.byte (#w e, 1); P.list (fn (_, i) => name (e, kTvar, i)) (#w e, ids); ty (e, t))

  (* the types of the IRs (Ty) *)
  fun irTy (e : enc, t : Ty.ty) : unit =
    let val w = #w e
    in
      case Ty.view t of
        Ty.Gen i => (P.byte (w, 0); name (e, kTvar, i))
      | Ty.Var i => (P.byte (w, 1); name (e, kTvar, i))
      | Ty.Con (s, n, args) => (P.byte (w, 2); name (e, kTycon, s); P.string (w, n); P.list (fn (_, a) => irTy (e, a)) (w, args))
      | Ty.Tuple ts => (P.byte (w, 3); P.list (fn (_, a) => irTy (e, a)) (w, ts))
      | Ty.Arrow (a, b) => (P.byte (w, 4); irTy (e, a); irTy (e, b))
      | Ty.ExnCon => P.byte (w, 5)
    end

  (* A constructor's information is written once, and so is its list of
     siblings -- every constructor of its datatype, which each of them has:
     written whole for each, a datatype of n constructors took n * n in the
     basis and as many lists read back (MLton's DotColor, 7 MB; issue 14) *)
  fun once (table : int StringMap.map ref, count : int ref, w : P.writer, key : string, write : unit -> unit) : unit =
    case StringMap.find (!table, key) of
      SOME i => (P.byte (w, 1); P.nat (w, i))
    | NONE => (P.byte (w, 0); write (); table := StringMap.insert (!table, key, !count); count := !count + 1)

  fun coninfo (e : enc, {name = n, tag, hasArg, ncons, isRef, siblings} : Ast.coninfo) =
    let
      val w = #w e
      val sibKey = String.concatWith " " (List.map (fn (s, b) => s ^ (if b then "+" else "-")) siblings)
      val key = String.concatWith " " [n, Int.toString tag, Bool.toString hasArg, Int.toString ncons, Bool.toString isRef, sibKey]
    in
      once (#cons e, #ncons e, w, key, fn () =>
        (P.string (w, n); P.nat (w, tag); P.bool (w, hasArg); P.nat (w, ncons); P.bool (w, isRef);
         once (#sibs e, #nsibs e, w, sibKey, fn () =>
           P.list (fn (w, (s, b)) => (P.string (w, s); P.bool (w, b))) (w, siblings))))
    end

  fun exninfo (e : enc, {name = n, stamp, isGlobal, hasArg, builtin = b} : Ast.exninfo) =
    let val w = #w e val a = #a e
    in P.string (w, n); P.bool (w, hasArg); nameTo (a, e, kStamp, stamp); P.bool (a, isGlobal); P.option P.int (a, b) end

  fun valstatus (e : enc, v : Env.valstatus) : unit =
    let val w = #w e
    in
      case v of
        Env.Val {scheme, stamp, global} => (P.byte (w, 0); ty (e, scheme); nameTo (#a e, e, kStamp, stamp); P.bool (#a e, global))
      | Env.Con {scheme, info} => (P.byte (w, 1); ty (e, scheme); coninfo (e, info))
      | Env.Exn {ty = t, info} => (P.byte (w, 2); ty (e, t); exninfo (e, info))
      | Env.Prim {scheme, name = n} => (P.byte (w, 3); ty (e, scheme); P.string (w, n))
      | Env.ConAsVal {scheme, info} => (P.byte (w, 4); ty (e, scheme); coninfo (e, info))
      | Env.ExnAsVal {ty = t, info} => (P.byte (w, 5); ty (e, t); exninfo (e, info))
    end

  fun tystatus (e : enc, Env.TyStr {fcn, cons}) : unit =
    (tyfcn (e, fcn); P.list (fn (w, (n, v)) => (P.string (w, n); valstatus (e, v))) (#w e, cons))

  (* an origin, into the sidecar *)
  fun writeOrigin' (w,origin)=case origin of Env.Unknown => P.byte (w,0)
    | Env.Named {unit,kind,name,span} => (P.byte (w,1);P.string (w,unit);P.string (w,kind);P.string (w,name);
        P.string (w,#file span);P.nat (w,#start span);P.nat (w,#stop span))
    | Env.Constrained (actual,spec) => (P.byte (w,2);writeOrigin' (w,actual);writeOrigin' (w,spec))
    | Env.Held {last,...} => writeOrigin' (w,last)
  fun writeOrigin (e : enc, origin) =
    (case origin of Env.Unknown => () | _ => #spans e := true; writeOrigin' (#side e, origin))

  (* ---- environments by reference (functors-units M11, part 2) ----

     A signature or a functor's summary was written whole, nested
     signatures and all: MLton's bases were 222 MB, 98% of it environments
     written before (E12). In the signatures and functors of a basis
     (refsOK), an environment that is a structure of a signature, renamed,
     is written as a reference to it: the signature by its unit (this one,
     one of those its header names) and its name, the path in it, and the
     renaming -- the image of each of the structure's own type names, in the
     order of their first occurrence in it, and its values' stamps and
     whether they are global, each list a byte where it is the structure's
     own, and its origins in the sidecar, which no renaming says. The
     structure is found as a fingerprint's reference finds one
     (candidateAt: the path its first value's stamp has in the unit that
     declared the signature), or by its first value's stamp among this
     unit's signatures written before (ownPaths); a functor's result, whose
     values are the summary's placeholders, among the structures its
     parameter was written as references to, by the names of their entries.
     renaming checks that reading the structure's names again makes the
     environment; where it does not, the environment is written whole, as
     before. A reference into a unit loaded in the place of the one the
     basis was written against (remapping) names that unit's signature, and
     the renaming's names are read by their paths as every other name of it
     is: an entry is taken where its usages hold, and the structure is in
     what one of them names -- the signature, or a signature or functor
     whose fingerprint holds it -- so it is the same there but for those
     names. *)
  datatype target = Here | Earlier of loaded
  val refsOK = ref false
  val () = CompilerState.cellRoot ("UnitBasis.refsOK", refsOK)
  (* this unit's signatures written so far, and the path each of their own
     values' stamps first has in them *)
  val ownSigs : SigMatch.sigma StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("UnitBasis.ownSigs", ownSigs)
  val ownPaths : (string * string list) IntTable.table ref = ref (IntTable.table 64)
  val () = CompilerState.refRoot ("UnitBasis.ownPaths", ownPaths, IntTable.copy)
  val ownLocals : int IntMap.map StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("UnitBasis.ownLocals", ownLocals)
  fun ownLocalsOf (n : string, sg : SigMatch.sigma) : int IntMap.map =
    case StringMap.find (!ownLocals, n) of
      SOME m => m
    | NONE => let val m = localsOf (#bound sg) in ownLocals := StringMap.insert (!ownLocals, n, m); m end
  (* a functor's parameter being written, or its result; and the structures
     its parameter was written as references to, and theirs, by the names
     of their entries *)
  val inParamB = ref false
  val () = CompilerState.cellRoot ("UnitBasis.inParamB", inParamB)
  val inResultB = ref false
  val () = CompilerState.cellRoot ("UnitBasis.inResultB", inResultB)
  val paramTargets : (target * string * string list * int IntMap.map * Env.env) list StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("UnitBasis.paramTargets", paramTargets)

  fun noteOwnSig (e : enc, n : string, sg : SigMatch.sigma) : unit =
    let
      val start = Vector.sub (#start e, kStamp)
      fun walk (path : string list, Env.Env {vals, strs, ...}) =
        (StringMap.app (fn v => case valueStamp v of
                                  SOME st => if st >= start andalso not (isSome (IntTable.find (!ownPaths, st)))
                                             then IntTable.insert (!ownPaths, st, (n, List.rev path)) else ()
                                | NONE => ()) vals;
         StringMap.appi (fn (m, c) => walk (m :: path, c)) strs)
    in ownSigs := StringMap.insert (!ownSigs, n, sg); walk ([], #env sg) end

  fun noteParamTarget (x as (tg, n, path, cl, c) : target * string * string list * int IntMap.map * Env.env) : unit =
    let
      val k = namesKey c
      val l = getOpt (StringMap.find (!paramTargets, k), [])
    in
      paramTargets := StringMap.insert (!paramTargets, k, l @ [x]);
      StringMap.appi (fn (m, sub) => noteParamTarget (tg, n, path @ [m], cl, sub)) (Env.strs c)
    end

  (* the structure en may be written as a reference to *)
  fun basisCandidate (e : enc, en : Env.env) : (target * string * string list * int IntMap.map * Env.env) option =
    case firstStamp en of
      NONE => NONE
    | SOME (q, st) =>
        if st >= Vector.sub (#start e, kStamp) then
          (case IntTable.find (!ownPaths, st) of
             SOME (n, strPath) =>
               (case (stripPath (q, strPath), StringMap.find (!ownSigs, n)) of
                  (SOME cpath, SOME sg) =>
                    Option.map (fn c => (Here, n, cpath, ownLocalsOf (n, sg), c)) (Env.findStr' (#env sg, cpath))
                | _ => NONE)
           | NONE => NONE)
        else
          Option.map (fn (u, n, sg, cpath, c) => (Earlier u, n, cpath, sigLocalsOf (#identity u ^ "\000" ^ n, sg), c))
                     (candidateAt (q, st))

  fun basisReference (e : enc, en : Env.env)
      : (target * string * string list * int list * renaming * Env.env) option =
    let
      fun check (tg, n, path, cl, c) =
        let
          val order = case tg of
                        Here => localOrder (cl, c)
                      | Earlier u => orderOf (#identity u ^ "\000" ^ n ^ "\000" ^ String.concatWith "." path, cl, c)
          val m = renaming (cl, c, en)
        in if List.all (fn st => IntMap.member (#phi m, st)) order then SOME (tg, n, path, order, m, c) else NONE end
        handle NoMatch => NONE
    in
      case basisCandidate (e, en) of
        SOME x => (case check x of
                     SOME r => (if !inParamB then noteParamTarget x else (); SOME r)
                   | NONE => NONE)
      | NONE =>
          if not (!inResultB) then NONE
          else
            let
              fun try [] = NONE
                | try (x :: rest) = (case check x of SOME r => SOME r | NONE => try rest)
            in try (getOpt (StringMap.find (!paramTargets, namesKey en), [])) end
    end

  (* A reference's names, as runs of numbers one after another: the values of a
     structure met for the first time are numbered in the order they are
     written, and a reference names thousands of them in MLton's functors,
     which took more than half of its bases one at a time *)
  fun nameRuns (a : P.writer, e : enc, k : int, names : int list) : unit =
    let
      fun place v =
        if v < Vector.sub (!builtin, k) then (0, v)
        else if v >= Vector.sub (#start e, k) then (1, ownNumber (e, k, v))
        else (2, importOf (e, k, v))
      fun runs ([], acc) = List.rev acc
        | runs (v :: rest, acc) =
            let
              val (t, n) = place v
              fun go (m, []) = (m, [])
                | go (m, l as x :: xs) =
                    let val (t', n') = place x
                    in if t' = t andalso n' = n + m then go (m + 1, xs) else (m, l) end
              val (m, left) = go (1, rest)
            in runs (left, (t, n, m) :: acc) end
    in P.list (fn (a, (t, n, m)) => (P.byte (a, t); P.int (a, n); P.nat (a, m))) (a, runs (names, [])) end

  (* A reference's stamps that are not its structure's: an earlier
     reference's of the unit by its place among those, 2 and the place, or 1
     and the runs. MLton's functors refer to the same structures over and
     over: of 9.25 million stamps in 9,616 such lists, 1.80 million are in
     lists the unit has not written before *)
  fun stampList (e : enc, stamps : int list) : unit =
    let
      val a = #a e
      val h = List.foldl (fn (x, h) => (h * 31 + x mod 1000003) mod 1000003) (List.length stamps) stamps
      val bucket = getOpt (IntTable.find (#stampLists e, h), [])
    in
      case List.find (fn (l, _) => l = stamps) bucket of
        SOME (_, i) => (P.byte (a, 2); P.nat (a, i))
      | NONE =>
          let val i = !(#nstampLists e)
          in
            IntTable.insert (#stampLists e, h, (stamps, i) :: bucket); #nstampLists e := i + 1;
            P.byte (a, 1); nameRuns (a, e, kStamp, stamps)
          end
    end

  (* flags, the same way *)
  fun flagRuns (a : P.writer, flags : bool list) : unit =
    let
      fun runs ([], acc) = List.rev acc
        | runs (f :: rest, acc) =
            let
              fun go (m, []) = (m, [])
                | go (m, l as x :: xs) = if x = f then go (m + 1, xs) else (m, l)
              val (m, left) = go (1, rest)
            in runs (left, (f, m) :: acc) end
    in P.list (fn (a, (f, m)) => (P.bool (a, f); P.nat (a, m))) (a, runs (flags, [])) end

  (* an environment written as a reference has its origins in the sidecar
     all the same: its own, and each of its structures' in the order of their
     names *)
  fun originTree (e : enc, Env.Env {strs, origins, ...}) : unit =
    (P.list (fn (_, (key, origin)) => (P.string (#side e, key); writeOrigin (e, origin))) (#side e, StringMap.listItemsi origins);
     List.app (fn (_, s) => originTree (e, s)) (StringMap.listItemsi strs))

  (* whether two environments of one shape have the same origins throughout *)
  fun sameOrigins (Env.Env {strs = s1, origins = o1, ...}, Env.Env {strs = s2, origins = o2, ...}) : bool =
    StringMap.listItemsi o1 = StringMap.listItemsi o2
    andalso ListPair.allEq (fn ((_, a), (_, b)) => sameOrigins (a, b)) (StringMap.listItemsi s1, StringMap.listItemsi s2)

  (* an environment: a byte, 0 and the environment whole, or 1 and a
     reference (above) *)
  fun env (e : enc, en as Env.Env {vals, tys, strs,origins}) : unit =
    let val w = #w e
    in
      case (if !refsOK then basisReference (e, en) else NONE) of
        SOME (tg, n, path, order, {phi, stamps, globals, cStamps, cGlobals}, c) =>
          (P.byte (w, 1);
           (case tg of
              Here => P.nat (w, 0)
            | Earlier u => (P.nat (w, 1 + sigUnit (e, #identity u)); #targets e := (u, n) :: !(#targets e)));
           P.string (w, n); P.list P.string (w, path);
           P.list (fn (_, st) => tyfcn (e, valOf (IntMap.find (phi, st)))) (w, order);
           if stamps = cStamps then P.byte (#a e, 0) else stampList (e, stamps);
           if globals = cGlobals then P.byte (#a e, 0) else (P.byte (#a e, 1); flagRuns (#a e, globals));
           (* its origins, where they are not those of the structure it is,
              which a signature's copies of its specifications keep *)
           if sameOrigins (c, en) then P.byte (#side e, 0) else (P.byte (#side e, 1); originTree (e, en)))
      | NONE =>
          (P.byte (w, 0);
           P.list (fn (w, (n, v)) => (P.string (w, n); valstatus (e, v))) (w, StringMap.listItemsi vals);
           P.list (fn (w, (n, t)) => (P.string (w, n); tystatus (e, t))) (w, StringMap.listItemsi tys);
           P.list (fn (w, (n, s)) => (P.string (w, n); env (e, s))) (w, StringMap.listItemsi strs);
           P.list (fn (_,(key,origin)) => (P.string (#side e,key);writeOrigin (e,origin))) (#side e,StringMap.listItemsi origins))
    end

  fun sigma (e : enc, {bound, env = en,origin} : SigMatch.sigma) : unit =
    (P.list (fn (_, c) => tycon (e, c)) (#w e, bound); env (e, en);writeOrigin (e,origin))

  (* ---- what of an environment is not the unit's start ---- *)

  (* the type name a constructor's scheme ends in *)
  fun resultTycon (t : T.ty) : int =
    case T.prune t of
      T.TArrow (_, r) => resultTycon r
    | T.TCon (c, _) => #stamp c
    | _ => ~1

  fun sameType (a : T.ty, b : T.ty) : bool =
    case (T.prune a, T.prune b) of
      (T.TVar r1, T.TVar r2) => r1 = r2
    | (T.TCon (c1, a1), T.TCon (c2, a2)) => #stamp c1 = #stamp c2 andalso ListPair.allEq sameType (a1, a2)
    | (T.TRecord f1, T.TRecord f2) =>
        ListPair.allEq (fn ((l1, t1), (l2, t2)) => l1 = l2 andalso sameType (t1, t2)) (f1, f2)
    | (T.TArrow (a1, b1), T.TArrow (a2, b2)) => sameType (a1, a2) andalso sameType (b1, b2)
    | _ => false

  fun sameVal (a : Env.valstatus, b : Env.valstatus) : bool =
    case (a, b) of
      (Env.Val x, Env.Val y) => #stamp x = #stamp y
    | (Env.Con x, Env.Con y) => #tag (#info x) = #tag (#info y) andalso #name (#info x) = #name (#info y)
                                andalso resultTycon (#scheme x) = resultTycon (#scheme y)
    | (Env.ConAsVal x, Env.ConAsVal y) => #tag (#info x) = #tag (#info y) andalso #name (#info x) = #name (#info y)
                                          andalso resultTycon (#scheme x) = resultTycon (#scheme y)
    | (Env.Exn x, Env.Exn y) => #stamp (#info x) = #stamp (#info y)
    | (Env.ExnAsVal x, Env.ExnAsVal y) => #stamp (#info x) = #stamp (#info y)
    | (Env.Prim x, Env.Prim y) => #name x = #name y andalso sameType (#scheme x, #scheme y)
    | _ => false

  fun sameTy (Env.TyStr a, Env.TyStr b) : bool =
    (case (#fcn a, #fcn b) of
       (T.TName c1, T.TName c2) => #stamp c1 = #stamp c2
     | (T.TAbbrev (i1, t1), T.TAbbrev (i2, t2)) => i1 = i2 andalso sameType (t1, t2)
     | _ => false)
    andalso ListPair.allEq (fn ((n1, v1), (n2, v2)) => n1 = n2 andalso sameVal (v1, v2)) (#cons a, #cons b)

  fun sameEnv (Env.Env a, Env.Env b) : bool =
    let
      fun same eq (m1, m2) =
        StringMap.numItems m1 = StringMap.numItems m2
        andalso StringMap.foldli (fn (n, x, ok) => ok andalso (case StringMap.find (m2, n) of
                                                                 SOME y => eq (x, y)
                                                               | NONE => false)) true m1
    in (if StringMap.isEmpty (#origins a) andalso StringMap.isEmpty (#origins b) then true
        else StringMap.listItemsi (#origins a)=StringMap.listItemsi (#origins b))
       andalso same sameVal (#vals a, #vals b) andalso same sameTy (#tys a, #tys b) andalso same sameEnv (#strs a, #strs b) end

  (* What of x is not as it is in base: x holds every name of base (an
     environment only grows from the unit's start), and those it binds
     otherwise are the delta, which the start plus the delta gives back. *)
  fun envDelta (base : Env.env, x : Env.env) : Env.env =
    let
      fun keep kind eq (bm, xm) = StringMap.filteri (fn (n, v) =>
        Env.originOf (base,kind,([],n))<>Env.originOf (x,kind,([],n)) orelse (case StringMap.find (bm, n) of
                                                               SOME b => not (eq (b, v))
                                                             | NONE => true)) xm
    in
      Env.make {origins=Env.origins x,vals = keep "v" sameVal (Env.vals base, Env.vals x), tys = keep "t" sameTy (Env.tys base, Env.tys x),
               strs = keep "s" sameEnv (Env.strs base, Env.strs x)}
    end

  (* ---- functors ---- *)

  (* A functor of this unit's, written whole the first time and then by
     the global of its function (a functor declared again leaves the
     first in the basis of those declared between) *)
  (* A body kept for a later unit to copy has its positions by offset, and
     the line table of the copy names them by line, from the source of this
     unit (Code): what the offsets do not say, which an edit that keeps every
     offset moves. The hash of the lines and columns is kept with the body, so
     that the unit's identity and the usages "inl" and "inlv" hold them. *)
  fun linePosition (lines : P.writer) (sp : Source.span) : unit =
    case Source.lineColOf sp of
      SOME (_, line, column) => (P.nat (lines, line); P.nat (lines, column))
    | NONE => ()

  (* A body's name for a hash, not for a reader: a built-in or an earlier
     unit's by its anchor, and the unit's own by its number, which numbers it
     as a reader will find it *)
  fun nameText (e : enc, k : int, v : int) : string =
    if v >= Vector.sub (#start e, k) then "#" ^ Int.toString (ownNumber (e, k, v)) else anchor (k, v)

  (* The hash of a body kept for a later unit to copy, whose Mid is in bytes:
     that Mid, what the copies a later unit makes take of each global the
     body names, which a change of makes the body another, and the lines of
     its positions (linePosition). Each one's primitive, the global it is and
     that one's, whether it is a function known by name, and the hash of a
     marked functor's function's body it calls. None of this is the
     basis's: no reader keeps it, so that a basis written again from what
     loading it left is the same bytes (exportAgain). *)
  fun bodyHash (e : enc, bytes : string, named : int list, lines : P.writer) : string =
    let
      val t = P.writer ()
      fun prim h = (P.option P.string (t, IntMap.find (!Translate.primAliases, h));
                    P.option P.string (t, IntTable.find (!Expand.primGlobals, h)))
    in
      P.string (t, bytes);
      P.list (fn (_, g) =>
                (P.string (t, nameText (e, kStamp, g)); prim g;
                 P.option (fn (_, h) => (P.string (t, nameText (e, kStamp, h)); prim h)) (t, IntTable.find (!Expand.globalAliases, g));
                 P.bool (t, IntMap.member (!Lower.knownBefore, g));
                 P.option P.string (t, inlineHash g)))
             (t, named);
      P.string (t, P.hash (P.contents lines));
      P.hash (P.contents t)
    end

  (* the bytes of w from p0 *)
  fun bytesFrom (w : P.writer, p0 : int) : string =
    CharArraySlice.vector (CharArraySlice.slice (!(#bytes w), p0, SOME (!(#used w) - p0)))

  fun funref (e : enc, f as Elaborate.FunInfo {code, ...}) : unit =
    let val w = #w e
    in
      if IntTable.find (#funsDone e, code) = NONE then
        (IntTable.insert (#funsDone e, code, ()); P.byte (w, 1); funcode (e, f))
      else (P.byte (w, 0); nameTo (#a e, e, kStamp, code))
    end

  (* A functor compiled to a function, which is its signature -- its
     parameter's, and its summary -- and the global of its function:
     nothing of its body, so that a unit whose body changed and whose
     signature did not keeps its identity *)
  and funcode (e : enc, Elaborate.FunInfo {param, paramSig, summary = {generated, result}, binding, code}) : unit =
    let
      val w = #w e
    in
      P.option P.string (w, param);
      paramTargets := StringMap.empty;
      inParamB := true; sigma (e, paramSig); inParamB := false;
      inResultB := true; sigma (e, {bound = generated, env = result, origin = Env.Unknown}); inResultB := false;
      paramTargets := StringMap.empty;
      writeOrigin (e, binding);
      nameTo (#a e, e, kStamp, code);
      #bodies e := (code, paramSig) :: !(#bodies e)
    end

  (* a copied body's hash, kept in the basis; written again as it was read
     (exportAgain) *)
  fun keepHash (e : enc, k : writing, g : int, p0 : int, named : int list, lines : P.writer) : unit =
    let
      val w = #w e
      (* the unit's own globals those are, numbered here however the hash
         comes, for a basis written again to number its names as this does *)
      val () = List.app (fn g => case IntTable.find (!Expand.globalAliases, g) of
                                   SOME h => if h >= Vector.sub (#start e, kStamp) then ignore (ownNumber (e, kStamp, h)) else ()
                                 | NONE => ()) named
      val h = case (#again k, inlineHash g) of
                (true, SOME h) => h
              | _ => bodyHash (e, bytesFrom (w, p0), named, lines)
    in P.string (w, h); IntTable.insert (!inlineHashes, g, h) end

  (* in the ABI layer, for each functor written: where it is marked to be
     inlined, its function's Mid, its globals and type names named as the basis
     names them, which makes every one a name a later unit may name; its
     parameter's open datatypes; and the hash of it all *)
  fun functorBody (e : enc, k : writing) (code : int, paramSig : SigMatch.sigma) : unit =
    P.option (fn (w, f) =>
                let
                  val p0 = !(#used w)
                  val named : int list ref = ref []
                  val seen : unit IntTable.table = IntTable.table 64
                  fun global s =
                    (if isSome (IntTable.find (seen, s)) then () else (IntTable.insert (seen, s, ()); named := s :: !named);
                     name (e, kStamp, s))
                  val lines = P.writer ()
                in
                  (* a position in the unit's own source by nothing but
                     that, which a unit taken from the cache names where
                     the source is then, as its code's (relocate): not by
                     the path the compile was given it by *)
                  MidCodec.write (w, {stamp = global, tycon = fn c => name (e, kTycon, c),
                                      tvar = fn v => name (e, kTvar, v),
                                      file = fn f => P.option P.string (w, if f = #file e then NONE else SOME f),
                                      position = linePosition lines, funName = #funName k}) f;
                  P.list (fn (_, c) => name (e, kTycon, c))
                         (w, List.filter Ty.isOpen (List.map #stamp (#bound paramSig)));
                  keepHash (e, k, code, p0, List.rev (!named), lines)
                end)
             (#w e, #body k code)

  (* A function marked to be inlined (functors-units M10): its global, and
     its Mid as a marked functor's function is written, and its hash (the
     usage "inlv") *)
  fun inlineValue (e : enc, k : writing, s : int, f : Mid.fundef) : unit =
    let
      val w = #w e
      val () = name (e, kStamp, s)
      val p0 = !(#used w)
      val named : int list ref = ref []
      val seen : unit IntTable.table = IntTable.table 64
      fun global g =
        (if isSome (IntTable.find (seen, g)) then () else (IntTable.insert (seen, g, ()); named := g :: !named);
         name (e, kStamp, g))
      (* a position's file: the unit's own by nothing, another unit's source
         (a functor's whose copy the function is) by that unit's name, which
         the reader makes where its source is then, so that the bytes do not
         depend on the path a compile was given a source by (S61) *)
      fun fileName f =
        if f = #file e then NONE
        else case List.find (fn (l : loaded) => #file l = f) (!units) of
               SOME l => SOME ("\001" ^ #name l)
             | NONE => SOME f
      val lines = P.writer ()
    in
      MidCodec.write (w, {stamp = global, tycon = fn c => name (e, kTycon, c),
                          tvar = fn v => name (e, kTvar, v),
                          file = fn f => P.option P.string (w, fileName f),
                          position = linePosition lines, funName = #funName k}) f;
      keepHash (e, k, s, p0, List.rev (!named), lines)
    end

  (* ---- overloading ---- *)

  fun overload (e : enc, (s, {kind, ops, literal} : Overload.entry)) : unit =
    let val w = #w e val a = #a e
    in
      name (e, kTycon, s); P.string (w, kind);
      P.list (fn (w, (n, i)) => (P.string (w, n);
                                 case i of
                                   Overload.Prim p => (P.byte (a, 0); P.string (a, p))
                                 | Overload.Global g => (P.byte (a, 1); nameTo (a, e, kStamp, g))))
             (w, StringMap.listItemsi ops);
      case literal of
        Overload.Bits b => (P.byte (a, 0); P.int (a, b))
      | Overload.Via g => (P.byte (a, 1); nameTo (a, e, kStamp, g))
    end

  (* ---- the tables, for each own name as the writing met it ---- *)

  (* of a type name, what the static layer says: its constructors, how they
     lie (layoutOf), and in the sidecar where it was declared *)
  fun staticTycon (e : enc, v : int) : unit =
    let
      val w = #w e
      val cs = IntMap.find (!Elaborate.dataCons, v)
    in
      P.option (P.list (fn (w, (n, s)) => (P.string (w, n); valstatus (e, s)))) (w, cs);
      P.option (fn (w, l) => P.list (fn (w, (t, n)) => (P.nat (w, t); P.option P.nat (w, n))) (w, l))
               (w, Option.map (fn l => layoutOf (v, l)) cs);
      writeOrigin (e, getOpt (IntMap.find (!Env.typeOrigins, v), Env.Unknown))
    end

  (* and what the ABI layer says of it *)
  fun abiTycon (e : enc, v : int) : unit =
    let val w = #w e
    in
      P.option (fn (w, {params, cons} : Ty.datatypeInfo) =>
                  (P.list (fn (_, i) => name (e, kTvar, i)) (w, params);
                   P.list (fn (w, (tag, n, a)) =>
                             (P.nat (w, tag); P.string (w, n);
                              P.option (fn (w, arg) =>
                                          case arg of
                                            Ty.FromElab t => (P.byte (w, 0); ty (e, t))
                                          | Ty.Direct t => (P.byte (w, 1); irTy (e, t))) (w, a)))
                          (w, cons)))
               (w, IntMap.find (!Ty.datatypes, v));
      P.option (fn (_, f) => tyfcn (e, f)) (w, IntTable.find (Ty.realizations, v));
      (* the layout a body gave an instance of its datatype (Ty.pinned) *)
      P.option (P.list (fn (w, (t, n)) => (P.nat (w, t); P.option P.nat (w, n)))) (w, IntMap.find (!Ty.pinned, v))
    end

  (* the static layer's table: each own type name as the writing met it, the
     queue oldest first until writing an entry adds no name. The queue's
     values wait for the ABI layer *)
  fun staticTables (e : enc) : unit =
    let
      val w = #w e
      fun drain () =
        let val (ts, others) = List.partition (fn (k, _) => k = kTycon) (!(#queue e))
        in
          case List.rev ts of
            [] => ()
          | items =>
              (#queue e := others;
               List.app (fn (_, v) => (#sTycons e := v :: !(#sTycons e); P.byte (w, 1); P.nat (w, ownNumber (e, kTycon, v));
                                       staticTycon (e, v))) items;
               drain ())
        end
    in drain (); P.byte (w, 0) end

  (* the ABI layer's: what it says of the type names the static layer entered,
     and then of each name as the writing met it, a type name no static layer
     names with what the static layer would have said of it *)
  fun abiTables (e : enc) : unit =
    let
      val w = #w e
      fun drain () =
        case List.rev (!(#queue e)) of
          [] => ()
        | items => (#queue e := []; List.app entry items; drain ())
      and entry (k, v) =
        if k = kStamp then
          (P.byte (w, 1); P.nat (w, ownNumber (e, k, v));
           P.option (fn (_, t) => ty (e, t)) (w, IntTable.find (Ty.binders, v));
           P.option (P.option (fn (_, t) => ty (e, t))) (w, IntTable.find (Ty.exnArgs, v));
           P.option P.string (w, IntMap.find (!Translate.primAliases, v));
           P.bool (w, IntMap.member (!Lower.knownBefore, v));
           (* the global it is (Expand.globalAliases) *)
           P.option (fn (_, h) => name (e, kStamp, h)) (w, IntTable.find (!Expand.globalAliases, v));
           P.option P.string (w, IntTable.find (!Expand.primGlobals, v)))
        else if k = kTycon then
          (P.byte (w, 3); P.nat (w, ownNumber (e, k, v)); staticTycon (e, v); abiTycon (e, v))
        else ()
    in
      List.app (fn v => (P.byte (w, 2); P.nat (w, ownNumber (e, kTycon, v)); abiTycon (e, v))) (List.rev (!(#sTycons e)));
      drain ();
      P.byte (w, 0)
    end

  (* ---- a unit's basis ---- *)

  (* What export gives: the bytes, the sidecar that goes with them (empty where
     no origin was recorded), the unit's identity, and the number each of its
     own names was given, for the code of the unit (relative) *)
  type exported = {pickle : string, sidecar : string, identity : string, provenance : string,
                   own : int IntTable.table vector, counts : int vector}

  (* What a unit's imports are, for its identity to hold: of each type name its
     fingerprint, of each value and exception what fingerprints say of one,
     by the anchors of both, and of each signature it refers to that
     signature's. Any of these that moves moves the identity, so a unit
     that keeps its identity is the same to its clients, whatever they
     read of an import through it; the identities of the units named have no
     part in it. A type variable is its place alone. *)
  fun importStamp (s : int) : string =
    case IntTable.find (!stampFps, s) of
      SOME f => f
    | NONE =>
        let
          val f = hashed "import" (fn w =>
            let
              fun prim h = (P.option P.string (w, IntMap.find (!Translate.primAliases, h));
                            P.option P.string (w, IntTable.find (!Expand.primGlobals, h)))
              fun ty t = fpTy (w, ref [], IntMap.empty, t)
            in
              P.string (w, anchor (kStamp, s)); prim s;
              P.bool (w, IntMap.member (!Lower.knownBefore, s));
              P.option (fn (_, h) => (P.string (w, anchor (kStamp, h)); prim h; P.bool (w, IntMap.member (!Lower.knownBefore, h))))
                       (w, IntTable.find (!Expand.globalAliases, s));
              (* what a copy of it is: itself a function kept to be copied, or
                 one through the globals that are others *)
              P.option P.string (w, inlineHash s);
              P.option P.string (w, Option.mapPartial inlineHash (Expand.inlinedValue s));
              P.option (fn (_, t) => ty t) (w, IntTable.find (Ty.binders, s));
              P.option (P.option (fn (_, t) => ty t)) (w, IntTable.find (Ty.exnArgs, s))
            end)
        in IntTable.insert (!stampFps, s, f); f end

  (* of an import that is a type name, and of a signature referred to, its
     fingerprint in the layer at hand *)
  fun importTycon (e : enc, w : P.writer) (s : int, _ : int, _ : int) : unit =
    P.string (w, case IntTable.find (#records e, s) of
                   SOME c => fpTycon (IntMap.empty, c)
                 | NONE => fpStampOnly s)
  fun importSig (w : P.writer) ({identity, ...} : loaded, n : string) : unit =
    (P.string (w, nameOfIdentity identity); P.string (w, n);
     P.string (w, case StringMap.find (!unitSigs, identity ^ "\000" ^ n) of
                    SOME sg => getOpt (memo (identity, "sig " ^ n, fn () => SOME (byReference (fn () => fpSigma sg))), "")
                  | NONE => bug ("a signature of no unit: " ^ n)))

  fun importsHash (e : enc) : string =
    let
      val w = P.writer ()
      val () = scratch := IntTable.table 16
    in
      List.app (importTycon (e, w)) (List.rev (!(Vector.sub (#importList e, kTycon))));
      P.nat (w, !(Vector.sub (#nimports e, kTvar)));
      List.app (fn (s, _, _) => P.string (w, importStamp s)) (List.rev (!(Vector.sub (#importList e, kStamp))));
      List.app (importSig w) (List.rev (!(#targets e)));
      hashAt ("imports", P.contents w)
    end

  (* the same of the static layer: its imports are the first of theirs, the
     ones it met, and what it says of each is its static fingerprint *)
  fun staticImports (e : enc, tycons : int, tvars : int) : string =
    inStatic (fn () =>
      let val w = P.writer ()
      in
        List.app (importTycon (e, w)) (List.take (List.rev (!(Vector.sub (#importList e, kTycon))), tycons));
        P.nat (w, tvars);
        List.app (importSig w) (List.rev (!(#targets e)));
        hashAt ("imports", P.contents w)
      end)

  (* write (k, {start, name, file, text, mode, delta, fixity}): the basis of
     the unit compiled since start, which declared delta and left the fixity
     given; name is how it is known, file how its spans name its source,
     text the source and mode how it was read *)
  fun write (k : writing, {start : start, name = uname : string, file : string, text : unit -> string, mode : Source.mode,
                           delta : Env.env, fixity : Fixity.env}) : exported = during "export" (fn () =>
    let
      val w = P.writer ()
      val a = P.writer ()
      val e : enc = {w = w, a = a, side = P.writer (), spans = ref false, start = #counters start,
                     own = Vector.tabulate (3, fn _ => IntTable.table 256),
                     count = Vector.tabulate (3, fn _ => ref 0), queue = ref [], names = ref StringMap.empty,
                     nnames = ref 0, refs = IntTable.table 64,
                     nameList = ref [], imports = Vector.tabulate (3, fn _ => IntTable.table 256),
                     nimports = Vector.tabulate (3, fn _ => ref 0), importList = Vector.tabulate (3, fn _ => ref []),
                     records = IntTable.table 64, targets = ref [], sigUnits = ref StringMap.empty, sigUnitList = ref [],
                     tycons = IntTable.table 256, ntycons = ref 0,
                     keys = IntTable.table 1024, nkeys = ref 0,
                     types = ref IntMap.empty, ntypes = ref 0, cons = ref StringMap.empty, ncons = ref 0,
                     sibs = ref StringMap.empty, nsibs = ref 0, funsDone = IntTable.table 16,
                     bodies = ref [], sTycons = ref [], stampLists = IntTable.table 64, nstampLists = ref 0, file = file}
      (* the static layer: fixity, the directives the unit added, newest first *)
      val directives = List.take (#list fixity, List.length (#list fixity) - List.length (#list (#fixity start)))
      val () = P.list (fn (w, (n, f)) => (P.string (w, n);
                                         case f of
                                           Fixity.Nonfix => P.byte (w, 0)
                                         | Fixity.Infix p => (P.byte (w, 1); P.nat (w, p))
                                         | Fixity.Infixr p => (P.byte (w, 2); P.nat (w, p))))
                      (w, directives)
      val () = env (e, delta)
      (* its signatures and functors, where an environment may be a
         reference to one written before *)
      val () = (refsOK := true; ownSigs := StringMap.empty; ownPaths := IntTable.table 64; ownLocals := StringMap.empty;
                paramTargets := StringMap.empty; inParamB := false; inResultB := false)
      fun aside () = (refsOK := false; ownSigs := StringMap.empty; ownPaths := IntTable.table 64; ownLocals := StringMap.empty;
                      paramTargets := StringMap.empty; inParamB := false; inResultB := false)
      val () = (P.list (fn (w, n) => (P.string (w, n);
                                      case StringMap.find (!Elaborate.sigs, n) of
                                        SOME s => (sigma (e, s); noteOwnSig (e, n, s))
                                      | NONE => bug ("no signature " ^ n))) (w, #sigs k);
                P.list (fn (w, n) => (P.string (w, n);
                                      case StringMap.find (!Elaborate.funs, n) of
                                        SOME f => funref (e, f)
                                      | NONE => bug ("no functor " ^ n))) (w, #funs k);
                aside ())
               handle x => (aside (); raise x)
      val before' = #overloads (#snapshot start)
      val () = P.list (fn (_, x) => overload (e, x))
                      (w, IntMap.listItemsi (IntMap.filteri (fn (s, _) => not (IntMap.member (before', s))) (!Overload.table)))
      val () = staticTables e
      val staticTycons = !(Vector.sub (#nimports e, kTycon))
      val staticTvars = !(Vector.sub (#nimports e, kTvar))
      (* the ABI layer, the rest of it *)
      val ea : enc = {w = a, a = a, side = #side e, spans = #spans e, start = #start e, own = #own e, count = #count e,
                      queue = #queue e, names = #names e, nnames = #nnames e, refs = #refs e, nameList = #nameList e,
                      imports = #imports e, nimports = #nimports e, importList = #importList e, records = #records e,
                      targets = #targets e, sigUnits = #sigUnits e, sigUnitList = #sigUnitList e,
                      tycons = #tycons e, ntycons = #ntycons e, keys = #keys e, nkeys = #nkeys e,
                      types = #types e, ntypes = #ntypes e, cons = #cons e, ncons = #ncons e, sibs = #sibs e, nsibs = #nsibs e,
                      funsDone = #funsDone e, bodies = #bodies e, sTycons = #sTycons e, stampLists = #stampLists e,
                      nstampLists = #nstampLists e, file = #file e}
      val () = List.app (functorBody (ea, k)) (List.rev (!(#bodies e)))
      (* the functions it declares that are marked to be inlined, as its
         expansion left them *)
      val () = P.list (fn (_, (s, f)) => inlineValue (ea, k, s, f)) (a, #values k)
      (* the schemes of the unit's globals those name that nothing else
         types (a copy's own): each as a function of no parameter whose
         result is the global's type *)
      val () = P.list (fn (w, (g, (vs, t))) =>
                         MidCodec.write (w, {stamp = fn s => name (ea, kStamp, s), tycon = fn c => name (ea, kTycon, c),
                                             tvar = fn v => name (ea, kTvar, v), file = fn _ => P.option P.string (w, NONE),
                                             position = fn _ => (), funName = fn _ => NONE})
                                        {name = g, tyvars = vs, params = [], result = t, body = Mid.Return (Mid.Atom Mid.Unit)})
                      (a, #schemes k)
      val () = abiTables ea
      val static = P.contents w
      val abi = P.contents a
      val counts = Vector.map ! (#count e)
      (* what its identity hashes: the name, the counts of its own, the
         body, and what its imports are *)
      val h = P.writer ()
      val () = (P.bytes (h, magic); P.nat (h, version); P.string (h, P.probe ()); P.string (h, uname))
      val named = P.contents h
      val () = (Vector.app (fn c => P.nat (h, c)) counts; P.nat (h, String.size static))
      val digest = hashAt ("identity", P.contents h ^ static ^ abi ^ importsHash e)
      (* the static layer's, which holds of what elaboration reads alone *)
      val staticDigest = hashAt ("identity", named ^ static ^ staticImports (e, staticTycons, staticTvars))
      (* the header: as hashed, with both hashes and the units and names of
         the imports *)
      val r = P.writer ()
      val () = (P.bytes (r, magic); P.nat (r, version); P.string (r, P.probe ()); P.string (r, uname); P.string (r, digest);
                P.string (r, staticDigest); P.list P.string (r, List.rev (!(#nameList e)));
                Vector.app (fn l => P.list (fn (w, (_, u, n)) => (P.nat (w, u); P.nat (w, n))) (r, List.rev (!l))) (#importList e);
                P.list (fn (w, i) => P.nat (w, valOf (StringMap.find (!(#names e), i)))) (r, List.rev (!(#sigUnitList e)));
                Vector.app (fn c => P.nat (r, c)) counts; P.nat (r, String.size static))
      val hashed = P.contents r ^ static ^ abi
      (* what the compile used of each kind, which loading puts aside
         first, and the hash of the source and the mode it was read in, by
         which the compiler library checks a source it is given against
         the basis (RuneCompiler.readUnit, readMid): none is the basis's,
         nor in its identity *)
      val used = Vector.tabulate (3, fn k => !(counter k) - Vector.sub (#counters start, k))
      val sourceHash = hashAt ("source", text ())
      val u = P.writer ()
      val () = Vector.app (fn c => P.nat (u, c)) used
      val () = P.string (u, sourceHash)
      val () = P.string (u, Source.modeName mode)
      val identity = uname ^ "@" ^ digest
    in
      {pickle = P.contents u ^ hashed, sidecar = if !(#spans e) then P.contents (#side e) else "", identity = identity,
       provenance=Link.provenance (!CompilerSettings.target,mode,sourceHash),own = #own e, counts = counts}
    end)

  (* export {start, name, file, text, mode, delta, fixity}: the basis of the
     unit just compiled *)
  fun export (a as {start : start, name : string, file : string, text : unit -> string, mode : Source.mode,
                    delta : Env.env, fixity : Fixity.env}) : exported =
    let
      (* names newest first, each once, at its newest *)
      fun distinct names =
        List.rev (List.foldl (fn (n, acc) => if List.exists (fn m => m = n) acc then acc else n :: acc) [] names)
    in
      (* signatures and functors, in the order the unit declared them, the
         last of each name *)
      write ({sigs = List.rev (distinct (!Elaborate.insertedSigs)), funs = List.rev (distinct (!Elaborate.insertedFuns)),
              values = List.mapPartial (fn s => Option.map (fn f => (s, f)) (IntTable.find (!Expand.declaredValues, s)))
                                       (!Expand.declaredOrder),
              schemes = !Expand.declaredSchemes, body = fn g => IntTable.find (!Expand.declaredBodies, g),
              funName = fn x => IntMap.find (!Translate.funNames, x), again = false}, a)
    end

  (* ---- a unit's code, by keys ---- *)

  (* The code of the unit just exported (x), its names made keys: its own by
     the numbers its basis gave them, and those the basis did not give --
     what no later unit can name -- numbers after those, in the order the
     code names them; an earlier unit's by that unit's identity and its
     number there (Link.unitCode) *)
  (* The names of the unit just exported (x) as the session has them once
     its basis is loaded (l): its own by the numbers its basis gave them,
     from where its range begins, and the rest as they are -- what its Mid
     is renamed by, to be one program with the units' after it (M7) *)
  fun sessionNames (x : exported, l : loaded) : {stamp : int -> int, tycon : int -> int, tvar : int -> int} =
    let
      fun f k s = case IntTable.find (Vector.sub (#own x, k), s) of
                    SOME n => Vector.sub (#base l, k) + n
                  | NONE => s
    in {stamp = f kStamp, tycon = f kTycon, tvar = f kTvar} end

  fun relative (x : exported, u : Link.sessionCode) : Link.unitCode =
    let
      val own = Vector.sub (#own x, kStamp)
      val start = Vector.sub (#counts x, kStamp)
      val private : int IntTable.table = IntTable.table 64
      val nprivate = ref 0
      fun key (s : int) : Link.key =
        if s = Link.next then Link.nextKey
        else
          case IntTable.find (own, s) of
            SOME n => {unit = #identity x, number = n}
          | NONE =>
              if s >= Vector.sub (!builtin, kStamp) then
                case rangeOf (kStamp, s) of
                  SOME (b, lu) => {unit = #identity lu, number = s - b}
                | NONE =>
                    {unit = #identity x,
                     number = case IntTable.find (private, s) of
                                SOME n => n
                              | NONE => let val n = start + !nprivate
                                        in IntTable.insert (private, s, n); nprivate := !nprivate + 1; n end}
              else bug ("a built-in name in a unit's code: " ^ Int.toString s)
      (* a global the unit sets is its own: no unit before it has it *)
      val () = List.app (fn s => if #unit (key s) = #identity x then () else bug "a global set by a unit is another's")
                        (#defines u)
      (* in the order of their places in the code, not of the session's
         stamps: the stamps of other units' names are those a session gave
         them as it loaded those units, so a unit compiled in two sessions
         would list them in two orders (found verifying HOL4's build) *)
      fun byPlace (place : 'a -> int) (l : 'a list) : 'a list =
        let val sorted = IntMap.listItems (List.foldl (fn (x, m) => IntMap.insert (m, place x, x)) IntMap.empty l)
        in if List.length sorted = List.length l then sorted else bug "two names of a unit's code at one place" end
    in
      {code = #code u, identity = #identity x,provenance=SOME (#provenance x),
       globals = byPlace #2 (List.map (fn (s, ix) => (key s, ix)) (#globals u)),
       imports = byPlace #1 (List.map (fn (ix, s) => (ix, key s)) (#imports u)),
       exports = byPlace #1 (List.map (fn (s, ix) => (#number (key s), ix)) (#exports u))}
    end

  (* ---- reading ---- *)

  type dec = {r : P.reader,                            (* the layer being read *)
              a : P.reader,                            (* the ABI layer *)
              side : P.reader option,                  (* the sidecar, where it has anything *)
              base : int vector, units : loaded vector, ntycons : int ref, tycons : T.tycon array ref,
              ntypes : int ref, types : T.ty array ref,    (* the types read, in the order written *)
              ncons : int ref, cons : Ast.coninfo array ref,
              nsibs : int ref, sibs : (string * bool) list array ref,
              imports : int vector vector,            (* per kind, the session's names of its imports *)
              sigUnits : int vector,                   (* the units the static layer refers to, by their places in units *)
              stampLists : int list array ref, nstampLists : int ref,   (* references' stamps read, by their places *)
              (* its signatures read so far, which a reference may name,
                 and the templates of their structures (renamedEnv) *)
              sigsRead : SigMatch.sigma StringMap.map ref, hereTemplates : template StringMap.map ref}

  fun rnameAt (r : P.reader, d : dec, k : int) : int =
    (case P.rbyte r of
        0 => P.rint r
      | 1 => Vector.sub (#base d, k) + P.rnat r
      | 2 =>
          let val i = P.rnat r
          in if i >= Vector.length (Vector.sub (#imports d, k)) then raise P.Bad "an import out of range"
             else Vector.sub (Vector.sub (#imports d, k), i)
          end
      | _ => raise P.Bad "not a name")

  fun rname (d : dec, k : int) : int = rnameAt (#r d, d, k)

  fun rtycon (d : dec) : T.tycon =
    let
      val r = #r d
      val arr = #tycons d
      val n = #ntycons d
    in
      case P.rbyte r of
        0 =>
          let
            val s = rname (d, kTycon)
            val nm = P.rstring r
            val ar = P.rnat r
            val eq = P.rbool r
            val c = {name = nm, stamp = s, arity = ar, eq = eq}
          in
            if !n >= Array.length (!arr) then
              arr := Array.tabulate (2 * Array.length (!arr) + 16,
                                     fn i => if i < Array.length (!arr) then Array.sub (!arr, i) else c)
            else ();
            Array.update (!arr, !n, c); n := !n + 1; c
          end
      | 1 => let val i = P.rnat r in if i < !n then Array.sub (!arr, i) else raise P.Bad "a type name out of range" end
      | _ => raise P.Bad "not a type name"
    end

  fun rkind (d : dec) : T.kind =
    case P.rbyte (#r d) of
      0 => T.KPlain
    | 1 => T.KRigid (P.rstring (#r d))
    | 2 => T.KOverload (P.rlist P.rstring (#r d))
    | _ => raise P.Bad "not a kind"

  fun rty (d : dec) : T.ty =
    let
      val r = #r d
      (* a type read whole, numbered as the writer numbered it *)
      fun keep (t : T.ty) : T.ty =
        let val arr = #types d val n = #ntypes d
        in
          if !n >= Array.length (!arr) then
            arr := Array.tabulate (2 * Array.length (!arr) + 64,
                                   fn i => if i < Array.length (!arr) then Array.sub (!arr, i) else t)
          else ();
          Array.update (!arr, !n, t); n := !n + 1; t
        end
    in
      case P.rbyte r of
        4 => let val i = P.rnat r in if i < !(#ntypes d) then Array.sub (!(#types d), i) else raise P.Bad "a type out of range" end
      | b => keep (rtyWhole (d, b))
    end
  and rtyWhole (d : dec, b : int) : T.ty =
    let val r = #r d
    in
      case b of
        0 =>
          let
            val id = rname (d, kTvar)
            val lv = P.rnat r
            val kind = rkind d
            val eq = P.rbool r
          in
            case IntTable.find (!tvars, id) of
              SOME cell => T.TVar cell
            | NONE =>
                let val cell = ref (T.Unbound {id = id, level = if lv = 0 then T.genericLevel else lv - 1, kind = kind, eq = eq})
                in IntTable.insert (!tvars, id, cell); T.TVar cell end
          end
      | 1 => let val c = rtycon d in T.TCon (c, P.rlist (fn _ => rty d) r) end
      | 2 => T.TRecord (P.rlist (fn r => let val l = P.rstring r in (l, rty d) end) r)
      | 3 => let val a = rty d in T.TArrow (a, rty d) end
      | _ => raise P.Bad "not a type"
    end

  fun rtyfcn (d : dec) : T.tyfcn =
    case P.rbyte (#r d) of
      0 => T.TName (rtycon d)
    | 1 => let val ids = P.rlist (fn _ => rname (d, kTvar)) (#r d) in T.TAbbrev (ids, rty d) end
    | _ => raise P.Bad "not a type function"

  fun rirTy (d : dec) : Ty.ty =
    let val r = #r d
    in
      case P.rbyte r of
        0 => Ty.gen (rname (d, kTvar))
      | 1 => Ty.var (rname (d, kTvar))
      | 2 => let val s = rname (d, kTycon) val n = P.rstring r in Ty.con (s, n, P.rlist (fn _ => rirTy d) r) end
      | 3 => Ty.tuple (P.rlist (fn _ => rirTy d) r)
      | 4 => let val a = rirTy d in Ty.arrow (a, rirTy d) end
      | 5 => Ty.exnCon
      | _ => raise P.Bad "not a type of the IRs"
    end

  (* what once wrote: the n-th of its kind again, or one read whole and
     numbered *)
  fun ronce (r : P.reader, arr : 'a array ref, n : int ref, read : unit -> 'a) : 'a =
    case P.rbyte r of
      1 => let val i = P.rnat r in if i < !n then Array.sub (!arr, i) else raise P.Bad "a shared entry out of range" end
    | 0 =>
        let val x = read ()
        in
          if !n >= Array.length (!arr) then
            arr := Array.tabulate (2 * Array.length (!arr) + 64, fn i => if i < Array.length (!arr) then Array.sub (!arr, i) else x)
          else ();
          Array.update (!arr, !n, x); n := !n + 1; x
        end
    | _ => raise P.Bad "not a shared entry"

  fun rconinfo (d : dec) : Ast.coninfo =
    let val r = #r d
    in
      ronce (r, #cons d, #ncons d, fn () =>
        let
          val n = P.rstring r
          val tag = P.rnat r
          val hasArg = P.rbool r
          val ncons = P.rnat r
          val isRef = P.rbool r
          val siblings = ronce (r, #sibs d, #nsibs d, fn () => P.rlist (fn r => let val s = P.rstring r in (s, P.rbool r) end) r)
        in {name = n, tag = tag, hasArg = hasArg, ncons = ncons, isRef = isRef, siblings = siblings} end)
    end

  fun rexninfo (d : dec) : Ast.exninfo =
    let
      val r = #r d
      val a = #a d
      val n = P.rstring r
      val hasArg = P.rbool r
      val stamp = rnameAt (a, d, kStamp)
      val isGlobal = P.rbool a
      val b = P.roption P.rint a
    in {name = n, stamp = stamp, isGlobal = isGlobal, hasArg = hasArg, builtin = b} end

  fun rvalstatus (d : dec) : Env.valstatus =
    case P.rbyte (#r d) of
      0 => let val s = rty d val st = rnameAt (#a d, d, kStamp) in Env.Val {scheme = s, stamp = st, global = P.rbool (#a d)} end
    | 1 => let val s = rty d in Env.Con {scheme = s, info = rconinfo d} end
    | 2 => let val t = rty d in Env.Exn {ty = t, info = rexninfo d} end
    | 3 => let val s = rty d in Env.Prim {scheme = s, name = P.rstring (#r d)} end
    | 4 => let val s = rty d in Env.ConAsVal {scheme = s, info = rconinfo d} end
    | 5 => let val t = rty d in Env.ExnAsVal {ty = t, info = rexninfo d} end
    | _ => raise P.Bad "not a value's status"

  fun rmap (d : dec) (f : dec -> 'a) : 'a StringMap.map =
    List.foldl (fn ((n, v), m) => StringMap.insert (m, n, v)) StringMap.empty
               (P.rlist (fn r => let val n = P.rstring r in (n, f d) end) (#r d))

  fun rtystatus (d : dec) : Env.tystatus =
    let val fcn = rtyfcn d
    in Env.TyStr {fcn = fcn, cons = P.rlist (fn r => let val n = P.rstring r in (n, rvalstatus d) end) (#r d)} end

  fun readOrigin' r = case P.rbyte r of 0 => Env.Unknown | 1 =>
    let val unit=P.rstring r val kind=P.rstring r val name=P.rstring r
        val file=P.rstring r val start=P.rnat r val stop=P.rnat r
    in Env.Named {unit=unit,kind=kind,name=name,span={file=file,start=start,stop=stop}} end
    | 2 => let val actual=readOrigin' r val spec=readOrigin' r in Env.Constrained (actual,spec) end
    | _ => raise P.Bad "invalid binding origin"
  fun readOrigin (d : dec) = case #side d of SOME r => readOrigin' r | NONE => Env.Unknown

  (* an environment read as a reference, with the origins the sidecar has of it *)
  fun withOrigins (side : P.reader, Env.Env {vals, tys, strs, ...}) : Env.env =
    let
      val origins = StringMap.fromList (P.rlist (fn r => let val key = P.rstring r
                                                             val origin = readOrigin' r
                                                         in (key, origin) end) side)
      val strs' = List.foldl (fn ((n, s), m) => StringMap.insert (m, n, withOrigins (side, s))) StringMap.empty
                             (StringMap.listItemsi strs)
    in Env.Env {vals = vals, tys = tys, strs = strs', origins = origins} end

  fun renv (d : dec) : Env.env =
    case P.rbyte (#r d) of
      0 =>
        let
          val vals = rmap d rvalstatus
          val tys = rmap d rtystatus
          val strs = rmap d renv
          val origins=case #side d of NONE => StringMap.empty | SOME side =>
            StringMap.fromList (P.rlist (fn r =>
              let val key=P.rstring r
                  val origin=readOrigin' r
              in (key,origin) end) side)
        in Env.Env {vals = vals, tys = tys, strs = strs,origins=origins} end
    | 1 => rreference d
    | _ => raise P.Bad "not an environment"

  (* an environment written as a reference (env): the structure renamed *)
  and rreference (d : dec) : Env.env =
    let
      val r = #r d
      val u = P.rnat r
      val n = P.rstring r
      val path = P.rlist P.rstring r
      val (sg, key) =
        if u = 0 then
          (case StringMap.find (!(#sigsRead d), n) of SOME sg => (sg, NONE) | NONE => raise P.Bad "a reference to a signature not read")
        else
          let
            val () = if u - 1 >= Vector.length (#sigUnits d) then raise P.Bad "a unit out of range" else ()
            (* the unit, or the one loaded in its place (remapping) *)
            val lu = Vector.sub (#units d, Vector.sub (#sigUnits d, u - 1))
          in
            case StringMap.find (!unitSigs, #identity lu ^ "\000" ^ n) of
              SOME sg => (sg, SOME (#identity lu ^ "\000" ^ n))
            | NONE => raise P.Bad "a reference to a signature its unit has not"
          end
      val c = case Env.findStr' (#env sg, path) of SOME c => c | NONE => raise P.Bad "a reference to a structure not there"
      val (order, tp) =
        case key of
          SOME k =>
            let val tk = k ^ "\000" ^ String.concatWith "." path val cl = sigLocalsOf (k, sg)
            in (orderOf (tk, cl, c), templateOf (tk, cl, c)) end
        | NONE =>
            let
              val tk = n ^ "\000" ^ String.concatWith "." path
              val cl = localsOf (#bound sg)
              val tp = case StringMap.find (!(#hereTemplates d), tk) of
                         SOME tp => tp
                       | NONE => let val tp = makeTemplate (cl, c)
                                 in #hereTemplates d := StringMap.insert (!(#hereTemplates d), tk, tp); tp end
            in (localOrder (cl, c), tp) end
      val images = P.rlist (fn _ => rtyfcn d) r
      val () = if List.length images = List.length order then () else raise P.Bad "a reference's renaming of another length"
      val phi = ListPair.foldl (fn (st, f, m) => IntMap.insert (m, st, f)) IntMap.empty (order, images)
      val a = #a d
      (* a run's names, last first, onto acc *)
      fun nameRun (acc, a) =
        let
          val t = P.rbyte a
          val n = P.rint a
          val m = P.rnat a
          fun at i = case t of
                       0 => n + i
                     | 1 => Vector.sub (#base d, kStamp) + n + i
                     | 2 => (Vector.sub (Vector.sub (#imports d, kStamp), n + i)
                             handle Subscript => raise P.Bad "an import out of range")
                     | _ => raise P.Bad "not a name"
          fun go (i, acc) = if i >= m then acc else go (i + 1, at i :: acc)
        in go (0, acc) end
      fun flagRun (acc, a) =
        let
          val f = P.rbool a
          val m = P.rnat a
          fun go (i, acc) = if i >= m then acc else go (i + 1, f :: acc)
        in go (0, acc) end
      fun runs (one : 'a list * P.reader -> 'a list) : 'a list =
        let
          fun go (0, acc) = List.rev acc
            | go (k, acc) = go (k - 1, one (acc, a))
        in go (P.rnat a, []) end
      val stamps = case P.rbyte a of
                     0 => NONE
                   | 1 =>
                       let
                         val l = runs nameRun
                         val arr = #stampLists d
                         val n = #nstampLists d
                       in
                         if !n >= Array.length (!arr) then
                           arr := Array.tabulate (2 * Array.length (!arr) + 16,
                                                  fn i => if i < Array.length (!arr) then Array.sub (!arr, i) else [])
                         else ();
                         Array.update (!arr, !n, l); n := !n + 1; SOME (ref l)
                       end
                   | 2 => let val i = P.rnat a
                          in if i < !(#nstampLists d) then SOME (ref (Array.sub (!(#stampLists d), i)))
                             else raise P.Bad "a reference's stamps out of range" end
                   | _ => raise P.Bad "not a reference's stamps"
      val globals = case P.rbyte a of
                      0 => NONE
                    | 1 => SOME (ref (runs flagRun))
                    | _ => raise P.Bad "not a reference's flags"
      val en = renamedEnv (tp, phi, stamps, globals) c
      fun empty (l : 'a list ref option) = case l of NONE => true | SOME x => List.null (!x)
    in
      if not (empty stamps andalso empty globals) then raise P.Bad "a reference's names left over"
      else
        case #side d of
          SOME side => (case P.rbyte side of
                          0 => en
                        | 1 => withOrigins (side, en)
                        | _ => raise P.Bad "not a reference's origins")
        | NONE => en
    end

  fun rsigma (d : dec) : SigMatch.sigma =
    let val bound = P.rlist (fn _ => rtycon d) (#r d)
        val env=renv d val origin=readOrigin d
    in {bound=bound,env=env,origin=origin} end

  (* ---- loading ---- *)

  (* What load gives: the unit, the environment it declared, and its
     fixity directives, newest first, which the caller adds to the start;
     and the names of the signatures and functors it declared *)
  type result = {unit : loaded, delta : Env.env, directives : (string * Fixity.fixity) list,
                 sigs : string list, funs : string list, overloads : int list,
                 values : int list, schemes : int list, static : string, sizes : int * int * int}
  (* what a load declared, which a walk over units that stay loaded declares
     again (the compiler library's analysis) *)
  type bindings = {sigs : (string * SigMatch.sigma) list, funs : (string * Elaborate.funinfo) list,
                   overloads : (int * Overload.entry) list}
  val lastBindings : bindings ref = ref {sigs = [], funs = [], overloads = []}
  val () = CompilerState.cellRoot ("UnitBasis.lastBindings", lastBindings)
  fun rebind ({sigs, funs, overloads} : bindings) : unit =
    (List.app (fn (n, s) => Elaborate.sigs := StringMap.insert (!Elaborate.sigs, n, s)) sigs;
     List.app (fn (n, f) => Elaborate.funs := StringMap.insert (!Elaborate.funs, n, f)) funs;
     List.app (fn (s, x) => Overload.table := IntMap.insert (!Overload.table, s, x)) overloads)

  (* What the unit of r declared is the session's: the names it bound, by
     the unit, for the usages of the units after it. The caller says when:
     at once, or once the unit has run (the REPL: a declaration that raises
     binds nothing) *)
  (* the keys of binders each bind sets, in order: what a scope of a build
     file added (Main, --build) *)
  val bindLog : string list ref = ref []
  val () = CompilerState.cellRoot ("UnitBasis.bindLog", bindLog)

  (* A unit's exports, at every depth: each one's key, its static layer's
     hash, and the hash of both layers, which is what a usage of it holds. In
     the order of the names; a unit whose static hashes are the same in
     analysis and in batch is one the editor and a compile can share *)
  fun exportHashes ({unit, delta, directives, sigs, funs, ...} : result) : (string * string * string) list =
    let
      val id = #identity unit
      val lines = ref []
      fun line (k, f : unit -> string) =
        let
          val () = scratch := IntTable.table 16
          val full = f ()
        in lines := (k, inStatic f, full) :: !lines end
      fun walk (prefix, Env.Env {vals, tys, strs, ...}) =
        (StringMap.appi (fn (n, v) => line ("v " ^ prefix ^ n, fn () => hashed "v" (fn w => fpVal (w, IntMap.empty, v)))) vals;
         StringMap.appi (fn (n, t) => line ("t " ^ prefix ^ n, fn () => hashed "t" (fn w => fpTyStr (w, IntMap.empty, t)))) tys;
         StringMap.appi (fn (n, c) => (line ("s " ^ prefix ^ n, fn () => fpEnv ((id, prefix ^ n ^ "."), c));
                                       walk (prefix ^ n ^ ".", c))) strs)
      val () = walk ("", delta)
      val () = List.app (fn (n, f) => line ("fix " ^ n, fn () => case f of
                                                                   Fixity.Nonfix => "nonfix"
                                                                 | Fixity.Infix p => "infix " ^ Int.toString p
                                                                 | Fixity.Infixr p => "infixr " ^ Int.toString p)) directives
      val () = List.app (fn n => case StringMap.find (!Elaborate.sigs, n) of
                                   SOME sg => line ("sig " ^ n, fn () => byReference (fn () => fpSigma sg))
                                 | NONE => ()) sigs
      val () = List.app (fn n => case StringMap.find (!Elaborate.funs, n) of
                                   SOME f => line ("fun " ^ n, fn () => getOpt (byReference (fn () => fpFunctor f), ""))
                                 | NONE => ()) funs
    in List.rev (!lines) end

  fun dumpLayers (r as {unit, ...} : result) : unit =
    case !layerDump of
      NONE => ()
    | SOME dir =>
        let
          val out = TextIO.openOut (OS.Path.joinDirFile {dir = dir, file = String.map (fn #"/" => #"%" | c => c) (#name unit)})
        in
          List.app (fn (k, s, f) => TextIO.output (out, k ^ "\t" ^ s ^ "\t" ^ f ^ "\n")) (exportHashes r);
          TextIO.output (out, "UNIT\t" ^ #static r ^ "\t" ^ #identity unit ^ "\t"
                              ^ (case #sizes r of (a, b, c) => String.concatWith " " (List.map Int.toString [a, b, c])) ^ "\n");
          TextIO.closeOut out
        end

  fun bind (r as {unit, delta, directives, sigs, funs, overloads, ...} : result) : unit =
    let
      val () = dumpLayers r
      val id = #identity unit
      fun put (kind, names) = List.app (fn n => (binders := StringMap.insert (!binders, kind ^ " " ^ n, id);
                                                 bindLog := (kind ^ " " ^ n) :: !bindLog)) names
    in
      put ("v", StringMap.listKeys (Env.vals delta));
      put ("t", StringMap.listKeys (Env.tys delta));
      put ("s", StringMap.listKeys (Env.strs delta));
      put ("fix", List.map #1 directives);
      put ("sig", sigs);
      put ("fun", funs);
      (* the types whose overloading it registered, by their names: a unit
         that resolved an operator or a constant at one used it, though it
         may never have named the unit (WideString.string, which
         widestring.sml registers and an earlier unit declares) *)
      put ("o", List.mapPartial (fn s => stableName (kTycon, s)) overloads)
    end

  (* ---- an entry against units it was not written against ---- *)

  (* What the incremental roadmap's M6 (the third part, step 3) loads an
     entry with whose usages hold and whose pickle names units the session
     has not -- a unit that changed since, which its usages held of all the
     same, by fingerprint: for each, the unit of the session of the same
     name, and each name of the old one, by kind and number, that name of
     the new one that the old's path reaches (oldPaths: what the cache keeps
     of an identity, pathsOf). A name with no path, or no name at its path
     in the new, is no remapping of it, and an entry that names it is a
     miss (rname). *)
  type remap = (string * loaded * int IntMap.map vector) list   (* the old identity, the new unit, its names *)

  (* the identities of the units a pickle names, from its header *)
  fun namedBy (pickle : string) : string list =
    let
      val r = P.reader pickle
      val _ = Vector.tabulate (3, fn _ => P.rnat r)
      val _ = P.rstring r   (* the hash of its source *)
      val _ = P.rstring r   (* its mode *)
      val () = if P.rbytes (r, 3) = magic then () else raise P.Bad "not a unit's basis"
      val () = if P.rnat r = version then () else raise P.Bad "a basis of another version"
      val () = if P.rstring r = P.probe () then () else raise P.Bad "a basis made by a compiler whose hash differs"
      val _ = P.rstring r   (* its name *)
      val _ = P.rstring r   (* its identity's hash *)
      val _ = P.rstring r   (* its static layer's *)
    in P.rlist P.rstring r end

  (* whether every usage holds by its binder and the entry's basis names
     only units of the session: an entry that needs nothing remapped. An
     identity moves with what it names, so a unit of the session may be the
     one its usages name and the units its basis names, by what they
     were, be others *)
  fun exactEntry (us : (string * string) list, pickle : string) : bool =
    exact us andalso (List.all (fn i => isSome (StringMap.find (!byIdentity, i))) (namedBy pickle)
                      (* what is wrong with its bytes, loading it says *)
                      handle P.Bad _ => true)

  val nameOf = nameOfIdentity

  (* the units an entry's code names other than itself *)
  fun namedByCode (u : Link.unitCode) : string list =
    List.foldl (fn ({unit, ...} : Link.key, acc) =>
                  if unit = #unit Link.nextKey orelse unit = #identity u orelse List.exists (fn i => i = unit) acc then acc
                  else unit :: acc)
               [] (List.map #1 (#globals u) @ List.map #2 (#imports u))

  (* Whether an entry may be loaded against a unit other than one it names:
     not in a program that may load units while it runs (Main), which names
     its units in its file as a build from source does, for a unit loaded
     into it -- compiled from source -- to find them by *)
  val remapAllowed = ref true
  val () = CompilerState.cellRoot ("UnitBasis.remapAllowed", remapAllowed)

  (* the remapping that loads an entry -- its basis pickle, its code u -- in
     the session, or Missing: of every unit either names *)
  fun remappingOf (named : string list, oldPaths : string -> (int * int * string) list option) : remap =
    if not (!remapAllowed) then [] else
    List.mapPartial
      (fn i =>
         if isSome (StringMap.find (!byIdentity, i)) then NONE
         else
           let
             val name = nameOf i
             val new = case List.find (fn (l : loaded) => #name l = name) (!units) of
                         SOME l => l
                       | NONE => raise Missing (i ^ " (no unit of its name)")
             val ps = case oldPaths i of SOME ps => ps | NONE => raise Missing (i ^ " (nothing kept of it)")
             val maps = Array.array (3, IntMap.empty)
             fun add (k, n, p) =
               case Option.mapPartial (fn reached => StringMap.find (reached, pathKey (k, p))) (StringMap.find (!byPath, #identity new)) of
                 SOME s => Array.update (maps, k, IntMap.insert (Array.sub (maps, k), n, s))
               | NONE => ()
           in List.app add ps; SOME (i, new, Array.vector maps) end)
      named
  fun remapping (pickle : string, u : Link.unitCode, oldPaths : string -> (int * int * string) list option) : remap =
    remappingOf (List.foldl (fn (i, acc) => if List.exists (fn j => j = i) acc then acc else acc @ [i])
                            (namedBy pickle) (namedByCode u), oldPaths)
  (* the same, of an entry with a basis and no code *)
  fun remappingBasis (pickle : string, oldPaths : string -> (int * int * string) list option) : remap =
    remappingOf (namedBy pickle, oldPaths)

  (* an entry's code, its keys of a remapped unit's names made the new
     unit's, or Missing where one has no new name *)
  fun remapKeys (u : Link.unitCode, remap : remap) : Link.unitCode =
    if List.null remap then u
    else
      let
        fun key (k as {unit, number} : Link.key) =
          case List.find (fn (i, _, _) => i = unit) remap of
            NONE => k
          | SOME (_, new, maps) =>
              (case IntMap.find (Vector.sub (maps, kStamp), number) of
                 SOME s => {unit = #identity new, number = s - Vector.sub (#base new, kStamp)}
               | NONE => raise Missing (unit ^ " (a name no path of it reaches)"))
      in
        {code = #code u, identity = #identity u,provenance= #provenance u, globals = List.map (fn (k, ix) => (key k, ix)) (#globals u),
         imports = List.map (fn (ix, k) => (ix, key k)) (#imports u), exports = #exports u}
      end

  (* An identity no unit of the session has: identity, or else identity~2,
     identity~3, ...: for a unit loaded again where it is loaded already --
     the same text against the same units, as a file the REPL uses again --
     whose globals must be its own, as a structure that names the first
     unit's must keep naming them. Its name is the same (nameOf). *)
  fun unused (identity : string) : string =
    let
      fun taken i = isSome (StringMap.find (!byIdentity, i))
      fun go n = let val i = identity ^ "~" ^ Int.toString n in if taken i then go (n + 1) else i end
    in if taken identity then go 2 else identity end

  (* code compiled as one unit, its own keys made those of the unit of
     identity to, as it is linked when it is loaded under another identity
     than its entry's (unused) *)
  fun renamed (u : Link.unitCode, to : string) : Link.unitCode =
    if #identity u = to then u
    else
      let
        fun key (k as {unit, number} : Link.key) = if unit = #identity u then {unit = to, number = number} else k
      in
        {code = #code u, identity = to, provenance = #provenance u, globals = List.map (fn (k, ix) => (key k, ix)) (#globals u),
         imports = List.map (fn (ix, k) => (ix, key k)) (#imports u), exports = #exports u}
      end

  (* load {pickle, sidecar, file, at}: the unit whose basis pickle is, loaded
     after the units of the session: its numbers given the names of the
     session that follow at's counters and what its compile used, its tables
     entered, its signatures, functors and overloading declared, and the
     unit registered; sidecar is what export gave beside the pickle, or ""
     for no origins; file is its source as spans name it now. Raises
     Missing where it names a unit the session has not, and Pickle.Bad
     where the bytes are not a basis. *)
  (* loadKnown (args, known, remap): known, where it is SOME, the unit's
     identity, which whoever has it need not work out again from the
     bytes: export, which just did, and an entry of the cache, which keeps
     it (functors-units, F2) *)
  fun load' ({pickle : string, sidecar : string, file : string, at : int vector}, known : string option, remap : remap) : result =
    let
      val r = P.reader pickle
      val side = if sidecar = "" then NONE else SOME (P.reader sidecar)
      val used = Vector.tabulate (3, fn _ => P.rnat r)
      val _ = P.rstring r   (* the hash of its source, for the compiler library *)
      val _ = P.rstring r   (* its mode *)
      val () = if P.rbytes (r, 3) = magic then () else raise P.Bad "not a unit's basis"
      val () = if P.rnat r = version then () else raise P.Bad "a basis of another version"
      (* made by a compiler whose hash gives other values: its identities and
         fingerprints are not this one's (Pickle.probe) *)
      val () = if P.rstring r = P.probe () then () else raise P.Bad "a basis made by a compiler whose hash differs"
      val uname = P.rstring r
      val digest = P.rstring r
      val staticDigest = P.rstring r
      val identity = case known of
                       SOME i => if String.isPrefix (uname ^ "@") i then i else raise P.Bad "another unit's identity"
                     | NONE => uname ^ "@" ^ digest
      val identities = P.rlist P.rstring r
      val us = Vector.fromList (List.map (fn i => case StringMap.find (!byIdentity, i) of
                                                    SOME u => u
                                                  | NONE => (case List.find (fn (o', _, _) => o' = i) remap of
                                                               SOME (_, new, _) => new
                                                             | NONE => raise Missing i)) identities)
      (* of each unit named, where it is one the pickle was not written
         against, its names by the old numbers, by kind *)
      val remaps = Vector.fromList (List.map (fn i => case List.find (fn (o', _, _) => o' = i) remap of
                                                        SOME (_, _, maps) => if isSome (StringMap.find (!byIdentity, i))
                                                                             then NONE else SOME maps
                                                      | NONE => NONE) identities)
      (* an import, as the session names it *)
      fun import k (r : P.reader) : int =
        let
          val u = P.rnat r
          val i = P.rnat r
          val () = if u >= Vector.length us then raise P.Bad "a unit out of range" else ()
          val lu = Vector.sub (us, u)
        in
          case Vector.sub (remaps, u) of
            SOME maps => (case IntMap.find (Vector.sub (maps, k), i) of
                            SOME s => s
                          | NONE => raise Missing (#identity lu ^ " (a name no path of it reaches)"))
          | NONE =>
              if i >= Vector.sub (#count lu, k) then raise P.Bad "a name out of its unit's range"
              else Vector.sub (#base lu, k) + i
        end
      val imports = Vector.tabulate (3, fn k => Vector.fromList (P.rlist (import k) r))
      val sigUnits = Vector.fromList (P.rlist (fn r => let val i = P.rnat r
                                                       in if i >= Vector.length us then raise P.Bad "a unit out of range" else i end) r)
      val counts = Vector.tabulate (3, fn _ => P.rnat r)
      val base = Vector.tabulate (3, fn k => Vector.sub (at, k) + Vector.sub (used, k))
      val () = List.app (fn k => counter k := Vector.sub (base, k) + Vector.sub (counts, k)) [kStamp, kTycon, kTvar]
      val staticSize = P.rnat r
      val staticEnd = !(#pos r) + staticSize
      val () = if staticEnd > String.size pickle then raise P.Bad "cut short" else ()
      val a : P.reader = {s = pickle, pos = ref staticEnd}
      val shared = {side = side, base = base, units = us, ntycons = ref 0, tycons = ref (Array.fromList []),
                    ntypes = ref 0, types = ref (Array.fromList []), ncons = ref 0, cons = ref (Array.fromList []),
                    nsibs = ref 0, sibs = ref (Array.fromList []),
                    imports = imports, sigUnits = sigUnits, stampLists = ref (Array.fromList []), nstampLists = ref 0,
                    sigsRead = ref StringMap.empty, hereTemplates = ref StringMap.empty}
      fun over (r : P.reader) : dec =
        {r = r, a = a, side = #side shared, base = #base shared, units = #units shared, ntycons = #ntycons shared,
         tycons = #tycons shared, ntypes = #ntypes shared, types = #types shared, ncons = #ncons shared, cons = #cons shared,
         nsibs = #nsibs shared, sibs = #sibs shared, imports = #imports shared, sigUnits = #sigUnits shared,
         stampLists = #stampLists shared, nstampLists = #nstampLists shared,
         sigsRead = #sigsRead shared,
         hereTemplates = #hereTemplates shared}
      val d = over r
      val da = over a
      (* RUNE_STATIC_LOAD: nothing of the ABI layer is entered in the tables,
         where no code is to be made of them *)
      val blank = !staticLoad andalso not (!Elaborate.makesCode)
      fun rfixity r =
        case P.rbyte r of
          0 => Fixity.Nonfix
        | 1 => Fixity.Infix (P.rnat r)
        | 2 => Fixity.Infixr (P.rnat r)
        | _ => raise P.Bad "not a fixity"
      val directives = P.rlist (fn r => let val n = P.rstring r in (n, rfixity r) end) r
      val delta = renv d
      val sigs = P.rlist (fn r => let val n = P.rstring r val sg = rsigma d
                                  in #sigsRead d := StringMap.insert (!(#sigsRead d), n, sg); (n, sg) end) r
      (* its functors, by the globals of their functions: written whole
         the first time, then by the global *)
      val ownFuns : Elaborate.funinfo IntMap.map ref = ref IntMap.empty
      val written : int list ref = ref []
      fun rfunref (r : P.reader) : Elaborate.funinfo =
        case P.rbyte r of
          1 => rfuncode r
        | 0 => let val code = rnameAt (a, d, kStamp)
               in case IntMap.find (!ownFuns, code) of
                    SOME f => f
                  | NONE => raise P.Bad "a functor named before it is declared"
               end
        | _ => raise P.Bad "not a functor"
      (* one compiled to a function (funcode) *)
      and rfuncode (r : P.reader) : Elaborate.funinfo =
        let
          val param = P.roption P.rstring r
          val paramSig = rsigma d
          val summary = let val {bound, env = result, ...} = rsigma d in {generated = bound, result = result} end
          val binding = readOrigin d
          val code = rnameAt (a, d, kStamp)
          val f = Elaborate.FunInfo {param = param, paramSig = paramSig, summary = summary, binding = binding, code = code}
        in ownFuns := IntMap.insert (!ownFuns, code, f); written := code :: !written; f end
      val funs = P.rlist (fn r => let val n = P.rstring r in (n, rfunref r) end) r
      val overloads =
        P.rlist (fn r =>
                   let
                     val s = rname (d, kTycon)
                     val kind = P.rstring r
                     val ops = P.rlist (fn r => let val n = P.rstring r
                                                in (n, case P.rbyte a of
                                                         0 => Overload.Prim (P.rstring a)
                                                       | 1 => Overload.Global (rnameAt (a, d, kStamp))
                                                       | _ => raise P.Bad "not an operator")
                                                end) r
                     val literal = case P.rbyte a of
                                     0 => Overload.Bits (P.rint a)
                                   | 1 => Overload.Via (rnameAt (a, d, kStamp))
                                   | _ => raise P.Bad "not a literal"
                   in
                     (s, {kind = kind, ops = List.foldl (fn ((n, i), m) => StringMap.insert (m, n, i)) StringMap.empty ops,
                          literal = literal})
                   end) r
      (* what a type name's static part says, in either layer (staticTycon) *)
      fun rstatic (dd : dec, c : int) : unit =
        let
          val r = #r dd
          val dcons = P.roption (P.rlist (fn r => let val n = P.rstring r in (n, rvalstatus dd) end)) r
          val layout = P.roption (fn r => P.rlist (fn r => let val t = P.rnat r in (t, P.roption P.rnat r) end) r) r
          val origin = readOrigin dd
        in
          Option.app (fn l => Elaborate.dataCons := IntMap.insert (!Elaborate.dataCons, c, l)) dcons;
          if blank then Option.app (fn l => Ty.pinLayout (c, l)) layout else ();
          case origin of Env.Unknown => () | _ => Env.typeOrigins := IntMap.insert (!Env.typeOrigins, c, origin)
        end
      fun staticEntries () =
        case P.rbyte r of
          0 => ()
        | 1 => let val c = Vector.sub (base, kTycon) + P.rnat r in rstatic (d, c); staticEntries () end
        | _ => raise P.Bad "not a table's entry"
      val () = staticEntries ()
      val () = if !(#pos r) = staticEnd then () else raise P.Bad "the static layer's length"
      (* the ABI layer, the rest of it: a marked functor's Mid, what an
         application of it in a later unit expands *)
      fun rbody (code : int) : unit =
        case P.rbyte a of
          0 => ()
        | 1 =>
            let
              val base = !privateNext
              val most = ref 0
              fun local' i = (if i > !most then most := i else (); base - i)
              val (body, names) =
                MidCodec.read (a, {stamp = fn () => rname (da, kStamp), tycon = fn () => rname (da, kTycon),
                                   tvar = fn () => rname (da, kTvar),
                                   file = fn () => getOpt (P.roption P.rstring a, file), local' = local'})
                handle MidCodec.Bad m => raise P.Bad m
              (* linted at the next unit's passes, always on (Pipeline.functorBodies) *)
              val () = if Pass.linting' 0 then MidLint.pendingBodies := body :: !MidLint.pendingBodies else ()
              val opens = P.rlist (fn _ => rname (da, kTycon)) a
              val h = P.rstring a
            in
              privateNext := base - !most - 1;
              IntTable.insert (!Expand.importedNames, code, names);
              List.app Ty.markOpen opens;
              IntTable.insert (!Expand.imported, code, body);
              IntTable.insert (!Elaborate.inlinedFunctions, code, ());
              IntTable.insert (!inlineHashes, code, h)
            end
        | _ => raise P.Bad "not an option"
      val () = List.app rbody (List.rev (!written))
      (* its functions marked to be inlined: what a later unit that names
         one copies (Expand.withInlined) *)
      val values =
        P.rlist (fn a =>
                   let
                     val s = rname (da, kStamp)
                     val base = !privateNext
                     val most = ref 0
                     fun local' i = (if i > !most then most := i else (); base - i)
                     fun fileOf NONE = file
                       | fileOf (SOME f) =
                           if String.isPrefix "\001" f
                           then let val n = String.extract (f, 1, NONE)
                                in case List.find (fn (l : loaded) => #name l = n) (!units) of
                                     SOME l => #file l
                                   | NONE => n
                                end
                           else f
                     val (body, names) =
                       MidCodec.read (a, {stamp = fn () => rname (da, kStamp), tycon = fn () => rname (da, kTycon),
                                          tvar = fn () => rname (da, kTvar),
                                          file = fn () => fileOf (P.roption P.rstring a), local' = local'})
                       handle MidCodec.Bad m => raise P.Bad m
                     val h = P.rstring a
                   in
                     privateNext := base - !most - 1;
                     IntTable.insert (!Expand.importedValueNames, s, names);
                     IntTable.insert (!Expand.importedValues, s, body);
                     Expand.anyImported := true;
                     IntTable.insert (!inlineHashes, s, h);
                     s
                   end) a
      val schemes =
        P.rlist (fn a =>
                   let
                     val ({name = g, tyvars, result, ...}, _) =
                       MidCodec.read (a, {stamp = fn () => rname (da, kStamp), tycon = fn () => rname (da, kTycon),
                                          tvar = fn () => rname (da, kTvar), file = fn () => (P.roption P.rstring a; file),
                                          local' = fn i => ~1 - i})
                       handle MidCodec.Bad m => raise P.Bad m
                   in IntTable.insert (!ToMid.importedSchemes, g, (tyvars, result)); g end) a
      (* what the ABI layer says of a type name *)
      fun rabi (c : int) : unit =
        let
          val dt = P.roption (fn a =>
                                let
                                  val params = P.rlist (fn _ => rname (da, kTvar)) a
                                  val cons = P.rlist (fn a =>
                                                        let
                                                          val tag = P.rnat a
                                                          val n = P.rstring a
                                                          val arg = P.roption (fn a => case P.rbyte a of
                                                                                         0 => Ty.FromElab (rty da)
                                                                                       | 1 => Ty.Direct (rirTy da)
                                                                                       | _ => raise P.Bad "not an argument") a
                                                        in (tag, n, arg) end) a
                                in {params = params, cons = cons} : Ty.datatypeInfo end) a
          val real = P.roption (fn _ => rtyfcn da) a
          val pin = P.roption (P.rlist (fn a => let val t = P.rnat a in (t, P.roption P.rnat a) end)) a
        in
          if blank then ()
          else
            (Option.app (fn l => Ty.pinLayout (c, l)) pin;
             Option.app (fn i => (Ty.extras := Ty.Unknown; Ty.datatypes := IntMap.insert (!Ty.datatypes, c, i))) dt;
             Option.app (fn f => IntTable.insert (Ty.realizations, c, f)) real)
        end
      (* the tables *)
      fun entries () =
        case P.rbyte a of
          0 => ()
        | 1 =>
            let
              val v = Vector.sub (base, kStamp) + P.rnat a
              val binder = P.roption (fn _ => rty da) a
              val exnArg = P.roption (P.roption (fn _ => rty da)) a
              val alias = P.roption P.rstring a
              val known = P.rbool a
              val same = P.roption (fn _ => rname (da, kStamp)) a
              val prim = P.roption P.rstring a
            in
              if blank then ()
              else
                (Option.app (fn h => IntTable.insert (!Expand.globalAliases, v, h)) same;
                 Option.app (fn p => IntTable.insert (!Expand.primGlobals, v, p)) prim;
                 Option.app (fn t => Ty.bindVar (v, t)) binder;
                 Option.app (fn e => Ty.bindExn (v, e)) exnArg;
                 Option.app (fn p => Translate.primAliases := IntMap.insert (!Translate.primAliases, v, p)) alias;
                 if known then Lower.knownBefore := IntMap.insert (!Lower.knownBefore, v, ()) else ());
              entries ()
            end
        | 2 => (rabi (Vector.sub (base, kTycon) + P.rnat a); entries ())
        | 3 => let val c = Vector.sub (base, kTycon) + P.rnat a in rstatic (da, c); rabi c; entries () end
        | _ => raise P.Bad "not a table's entry"
      val () = entries ()
      val () = if P.atEnd a then () else raise P.Bad "bytes after the basis"
      val () = case side of
                 SOME x => if P.atEnd x then () else raise P.Bad "bytes after the sidecar"
               | NONE => ()
      (* declared: signatures, functors, overloading *)
      val () = List.app (fn (n, s) => Elaborate.sigs := StringMap.insert (!Elaborate.sigs, n, s)) sigs
      val () = List.app (fn (n, f) => Elaborate.funs := StringMap.insert (!Elaborate.funs, n, f)) funs
      val () = List.app (fn (s, x) => Overload.table := IntMap.insert (!Overload.table, s, x)) overloads
      val u : loaded = {identity = identity, name = uname, file = file, base = base, count = counts}
    in
      lastBindings := {sigs = sigs, funs = funs, overloads = overloads};
      register u;
      notePaths (u, delta, sigs);
      {unit = u, delta = delta, directives = directives, sigs = List.map #1 sigs, funs = List.map #1 funs,
       overloads = List.map #1 overloads, values = values, schemes = schemes, static = staticDigest,
       sizes = (staticSize, String.size pickle - staticEnd, String.size sidecar)}
    end
    handle Overflow => raise P.Bad "a number out of range"
         | Subscript => raise P.Bad "out of range"

  fun loadKnown (args, known : string option, remap : remap) : result = during "load" (fn () => load' (args, known, remap))
  fun loadAgainst (args, remap : remap) : result = loadKnown (args, NONE, remap)
  fun load args : result = loadKnown (args, NONE, [])

  (* ---- a session whose units stay loaded between checks ---- *)

  fun isLoaded (identity : string) : bool = StringMap.member (!byIdentity, identity)

  (* The units named out of the session: what the tables hold of their names
     goes (abandon's, the paths, the fingerprints of their type names, the
     cells of their type variables), with the memos, and the counters stay,
     since a name is never used twice. What the session had of each, for the
     entries that name them: pathsOf. *)
  fun truncate (gone : string list) : (string * (int * int * string) list) list =
    let
      val dead = List.foldl (fn (i, m) => StringMap.insert (m, i, ())) StringMap.empty gone
      fun isGone (u : loaded) = StringMap.member (dead, #identity u)
      val leaving = List.filter isGone (!units)
      val kept = List.map (fn u => (#identity u, pathsOf u)) leaving
      val top = counters ()
      val low = List.foldl (fn (u : loaded, low) => Vector.tabulate (3, fn k => Int.min (Vector.sub (low, k), Vector.sub (#base u, k)))) top leaving
      fun stays (rs : (int * int * loaded) vector list) =
        List.foldl (fn ((b, c, u), pieces) => if isGone u then pieces else addRange (pieces, (b, c, u))) []
          (List.concat (List.rev (List.map (fn piece => Vector.foldr (op ::) [] piece) rs)))
    in
      units := List.filter (not o isGone) (!units);
      List.app (fn u => byIdentity := StringMap.remove (!byIdentity, #identity u)) leaving;
      List.app (fn k => Array.update (ranges, k, stays (Array.sub (ranges, k)))) [kStamp, kTycon, kTvar];
      List.app (fn u => byPath := StringMap.remove (!byPath, #identity u)) leaving;
      unitSigs := StringMap.filteri (fn (key, _) => not (StringMap.member (dead, hd (String.fields (fn c => c = #"\000") key)))) (!unitSigs);
      if List.null leaving then ()
      else (IntTable.removeRange (Vector.sub (paths, kStamp), Vector.sub (low, kStamp), Vector.sub (top, kStamp));
            IntTable.removeRange (Vector.sub (paths, kTycon), Vector.sub (low, kTycon), Vector.sub (top, kTycon));
            IntTable.removeRange (tyconFps, Vector.sub (low, kTycon), Vector.sub (top, kTycon));
            IntTable.removeRange (!tvars, Vector.sub (low, kTvar), Vector.sub (top, kTvar));
            abandon low; setCounters top);
      fpMemo := StringMap.empty; refMemo := StringMap.empty; schemeMemo := IntMap.empty; stampFps := IntTable.table 64;
      sigLocals := StringMap.empty; targetOrders := StringMap.empty; templates := StringMap.empty;
      kept
    end

  (* The basis of the unit just loaded (l), written again from what loading it
     left in the session: export of load. It leaves the session as it found
     it. A basis holds what its readers keep and nothing else, so of a unit
     compiled against the session this is the bytes it was loaded from
     (sameAgain); of an entry loaded across a unit that changed it names the
     new unit, and is what compiling it would give. *)
  fun exportAgain ({start : start, name : string, file : string, mode : Source.mode}, l : result) : exported =
    let
      val names : string IntTable.table = IntTable.table 64
      fun named table key =
        Option.app (List.app (fn (x, n) => IntTable.insert (names, x, n))) (IntTable.find (table, key))
      val () = List.app (named (!Expand.importedValueNames)) (#values l)
      val () = List.app (fn n => case StringMap.find (!Elaborate.funs, n) of
                                   SOME (Elaborate.FunInfo {code, ...}) => named (!Expand.importedNames) code
                                 | NONE => ()) (#funs l)
    in
      write ({sigs = #sigs l, funs = #funs l,
              values = List.map (fn s => (s, valOf (IntTable.find (!Expand.importedValues, s)))) (#values l),
              schemes = List.map (fn g => (g, valOf (IntTable.find (!ToMid.importedSchemes, g)))) (#schemes l),
              body = fn g => IntTable.find (!Expand.imported, g),
              funName = fn x => IntTable.find (names, x), again = true},
             {start = start, name = name, file = file, text = fn () => "", mode = mode, delta = #delta l,
              fixity = Fixity.extend (#fixity start, #directives l)})
    end

  (* a pickle's basis, past what its compile counted and its source's hash *)
  fun basisOf (pickle : string) : string =
    let
      val r = P.reader pickle
      val _ = Vector.tabulate (3, fn _ => P.rnat r)
      val _ = P.rstring r
      val _ = P.rstring r
    in String.extract (pickle, !(#pos r), NONE) end

  (* a level 2 check: a unit's basis is what writing what it loads as gives *)
  fun sameAgain (a, l : result) (pickle : string) : unit =
    let
      val bytes = basisOf pickle
      val again = basisOf (#pickle (exportAgain (a, l)))
    in
      if bytes = again then ()
      else
        let
          fun first i = if i >= size bytes orelse i >= size again orelse String.sub (bytes, i) <> String.sub (again, i) then i
                        else first (i + 1)
        in Error.bug ("a basis written again from what it loads as differs at byte " ^ Int.toString (first 0) ^ " of "
                      ^ Int.toString (size bytes) ^ " and " ^ Int.toString (size again) ^ ": " ^ #name a) end
    end
end
