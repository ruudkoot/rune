(* Implements: HS_LANGUAGE *)
structure HsLanguage :> HS_LANGUAGE =
struct
  datatype edition = Haskell98 | Haskell2010

  datatype feature =
      CycleDefaultScc
    | DoAndIfThenElse
    | EmptyDataDecls
    | ForeignFunctionInterface
    | GreatestFixpointNames
    | HierarchicalModules
    | NPlusKPatterns
    | PatternGuards
    | RelaxedPolyRec

  datatype step = On of feature | Off of feature

  datatype reading = Edition of edition | Steps of step list | Unknown

  type setting = {edition : edition, steps : step list}

  exception Refused of int * string

  fun featureName f =
    case f of
      CycleDefaultScc => "--cycle-default=scc"
    | DoAndIfThenElse => "DoAndIfThenElse"
    | EmptyDataDecls => "EmptyDataDecls"
    | ForeignFunctionInterface => "ForeignFunctionInterface"
    | GreatestFixpointNames => "--names=greatest"
    | HierarchicalModules => "HierarchicalModules"
    | NPlusKPatterns => "NPlusKPatterns"
    | PatternGuards => "PatternGuards"
    | RelaxedPolyRec => "RelaxedPolyRec"

  fun editionName Haskell98 = "Haskell98"
    | editionName Haskell2010 = "Haskell2010"

  (* every feature, in order of its name: the canonical order *)
  val all =
    let
      val fs = [CycleDefaultScc, DoAndIfThenElse, EmptyDataDecls, ForeignFunctionInterface, GreatestFixpointNames,
                HierarchicalModules, NPlusKPatterns, PatternGuards, RelaxedPolyRec]
      fun insert (f, []) = [f]
        | insert (f, g :: gs) = if String.< (featureName f, featureName g) then f :: g :: gs else g :: insert (f, gs)
    in
      List.foldl insert [] fs
    end

  fun member (f, fs) = List.exists (fn g => g = f) fs

  (* an edition's own set: the Report's rules that rhc tests by a feature
     (GHC's languageExtensions of the edition, but for what GHC adds to
     the Reports) *)
  fun own Haskell98 = [NPlusKPatterns]
    | own Haskell2010 = [DoAndIfThenElse, EmptyDataDecls, ForeignFunctionInterface, HierarchicalModules, PatternGuards,
                         RelaxedPolyRec]

  type t = {edition : edition, set : feature list}

  fun resolve (e, steps) =
    let
      fun step (On f, s) = if member (f, s) then s else f :: s
        | step (Off f, s) = List.filter (fn g => g <> f) s
      val s = List.foldl step (own e) steps
    in
      {edition = e, set = List.filter (fn f => member (f, s)) all}
    end

  fun ofEdition e = resolve (e, [])
  fun edition ({edition, ...} : t) = edition
  fun features ({set, ...} : t) = set
  fun has ({set, ...} : t, f) = member (f, set)
  fun same (a : t, b : t) = #set a = #set b

  fun canonical ({set, ...} : t) = String.concatWith "," (List.map featureName set)

  (* braced, so that the empty set is a key too, not Haskell 98's own *)
  fun key t = if same (t, ofEdition Haskell98) then "" else "{" ^ canonical t ^ "}"

  (* ---- Names ---- *)

  (* the features a name of GHC's that rhc implements names; rhc's own
     have no name a pragma writes (D8), nor has HierarchicalModules, which
     is no name of GHC's (D4) *)
  val named = [DoAndIfThenElse, EmptyDataDecls, ForeignFunctionInterface, NPlusKPatterns, PatternGuards, RelaxedPolyRec]

  fun read name =
    case List.find (fn e => editionName e = name) [Haskell98, Haskell2010] of
      SOME e => Edition e
    | NONE =>
        case List.find (fn f => featureName f = name) named of
          SOME f => Steps [On f]
        | NONE =>
            if String.isPrefix "No" name then
              case List.find (fn f => featureName f = String.extract (name, 2, NONE)) named of
                SOME f => Steps [Off f]
              | NONE => Unknown
            else Unknown

  (* ---- A module's language ---- *)

  fun ofSetting ({edition, steps} : setting) = resolve (edition, steps)

  fun stepText (On f) = "+" ^ featureName f
    | stepText (Off f) = "-" ^ featureName f

  fun settingKey ({edition, steps} : setting) =
    if edition = Haskell98 andalso null steps then ""
    else String.concatWith " " (editionName edition :: List.map stepText steps)

  fun ofHeader ({edition = base, steps} : setting, names : {name : string, at : int} list) =
    let
      val e = List.foldl (fn ({name, ...}, e) => case read name of Edition e' => e' | _ => e) base names
      fun one ({name, at}, acc) =
        case read name of
          Edition _ => acc
        | Steps s => acc @ s
        | Unknown =>
            raise Refused (at, "the language `" ^ name ^ "` of a LANGUAGE pragma, which rhc does not know: a module " ^
                               "that asks for a feature rhc does not support is refused (12.3)")
      (* the 98 rule (D6): a module of Haskell 98 reads only the editions
         its header names *)
      val header = if e = Haskell98 then [] else List.foldl one [] names
    in
      resolve (e, steps @ header)
    end
end
