(* The description of the compiler's codecs (the build-system roadmap's
   D21, M5; docs/units.md, Codecs), from which bin/rune-codecs writes the
   parts of lib/compiler/driver/unitbasis.sml, lib/compiler/core/midcodec.sml
   and lib/compiler/driver/unitmid.sml marked as generated (make codecs;
   make check-codecs fails where they are not what this gives).

   Three families. basis: a unit's basis (UnitBasis), each field to its
   layer (D1) -- the layer being written, the ABI layer, or the sidecar --
   with its fingerprint, the canonical bytes of the fields a layer's hash
   holds, and its sameness, what makes two bindings one (envDelta); a
   fingerprint's reads of the compiler's tables are a codec written by hand
   (valFacts), as is every table of a basis (staticTables, abiTables), and
   so are a type (keyed, its variables shared) and an environment written as
   a reference to a signature's structure. plain: what a basis's sidecar
   holds of a binding's origin. mid: a function of Mid (MidCodec, a marked
   functor's body and an inline function's) and a unit's Mid (UnitMid), its
   names written and read by the caller's hooks. *)
structure CodecCompiler =
struct
  open Codec
  infix 1 |>

  (* ---- the types ---- *)

  (* the elaborator's types, a type function *)
  val tyfcn =
    sum ("tyfcn", "T.tyfcn",
         [args ("T.TName", [field ("c", Leaf "tycon")])
            |> fingerprint (SOME 13, [FpField (Both, "c")], [])
            |> sameness ([SameField "c"], []),
          args ("T.TAbbrev", [field ("ids", List (Leaf "tvar")), field ("t", Leaf "ty")])
            |> fingerprint (SOME 14, [FpText (Both, "P.nat (w, List.length {ids})"), FpText (Both, "fpTy (w, ref {ids}, local', {t})")], [])
            |> sameness ([SameField "ids", SameField "t"], [])])

  (* a constructor's information: its fingerprint and its sameness its tag
     and name; the rest its type's definition says *)
  val coninfo =
    recordType ("coninfo", "Ast.coninfo",
                record ("", [field ("name", Leaf "string"), field ("tag", Leaf "nat"), field ("hasArg", Leaf "bool"),
                             field ("ncons", Leaf "nat"), field ("isRef", Leaf "bool"),
                             field ("siblings", Shared ("sibs", List (Tuple [Leaf "string", Leaf "bool"])))])
                  |> fingerprint (NONE, [FpField (Both, "name"), FpText (Both, "P.int (w, {tag})")],
                                  [("hasArg", "its scheme says whether it has an argument"),
                                   ("ncons", "its type's definition has every constructor"),
                                   ("isRef", "its type's definition says which type it makes"),
                                   ("siblings", "its type's definition has every constructor")])
                  |> sameness ([SameField "tag", SameField "name"],
                               [("hasArg", "of one tag and name of one type, the same"), ("ncons", "the same"),
                                ("isRef", "the same"), ("siblings", "the same")]))

  (* an exception's: it is its stamp, by its anchor in either layer's
     fingerprint, empty in the static layer's *)
  val exninfo =
    recordType ("exninfo", "Ast.exninfo",
                record ("", [field ("name", Leaf "string"), field ("hasArg", Leaf "bool"), abi ("stamp", Leaf "stamp"),
                             abi ("isGlobal", Leaf "bool"), abi ("builtin", Option (Leaf "int"))])
                  |> fingerprint (NONE, [FpField (Both, "stamp")],
                                  [("name", "the binding's name says it"), ("hasArg", "its type says it"),
                                   ("isGlobal", "where its stamp lives, which the stamp's anchor says"),
                                   ("builtin", "a built-in exception's stamp is a built-in name")])
                  |> sameness ([SameField "stamp"],
                               [("name", "an exception is its stamp"), ("hasArg", "the same"), ("isGlobal", "the same"),
                                ("builtin", "the same")]))

  (* a value's status. A value is its stamp, and its fingerprint its anchor
     and what the compiler's tables say of the stamp (valFacts), neither in
     the static layer's; a constructor its tag and name and the type it
     makes; a primitive its name and type *)
  fun conLike (con, tag) =
    record (con, [field ("scheme", Leaf "ty"), field ("info", Shared ("cons", Type "coninfo"))])
      |> fingerprint (SOME tag, [FpField (Both, "info"), FpField (Both, "scheme")], [])
      |> sameness ([SameField "info", SameVia ("resultTycon", "scheme")], [])
  fun exnLike (con, tag) =
    record (con, [field ("ty", Leaf "ty"), field ("info", Type "exninfo")])
      |> fingerprint (SOME tag, [FpField (Both, "info"), FpField (Both, "ty")], [])
      |> sameness ([SameField "info"], [("ty", "an exception is its stamp")])
  val valstatus =
    sum ("valstatus", "Env.valstatus",
         [record ("Env.Val", [field ("scheme", Leaf "ty"), abi ("stamp", Leaf "stamp"), abi ("global", Leaf "bool")])
            |> fingerprint (SOME 20, [FpField (Full, "stamp"), FpField (Both, "scheme"), FpText (Full, "valFacts (w, {stamp})")],
                            [("global", "where the value lives, which its anchor says")])
            |> sameness ([SameField "stamp"], [("scheme", "a value is its stamp"), ("global", "the same")]),
          conLike ("Env.Con", 21),
          exnLike ("Env.Exn", 22),
          record ("Env.Prim", [field ("scheme", Leaf "ty"), field ("name", Leaf "string")])
            |> fingerprint (SOME 23, [FpField (Both, "name"), FpField (Both, "scheme")], [])
            |> sameness ([SameField "name", SameField "scheme"], []),
          conLike ("Env.ConAsVal", 24),
          exnLike ("Env.ExnAsVal", 25)])

  val tystatus =
    recordType ("tystatus", "Env.tystatus",
                record ("Env.TyStr", [field ("fcn", Type "tyfcn"), field ("cons", List (Tuple [Leaf "string", Type "valstatus"]))])
                  |> fingerprint (NONE, [FpField (Both, "fcn"), FpField (Both, "cons")], [])
                  |> sameness ([SameField "fcn", SameField "cons"], []))

  (* an environment, written whole (a reference is UnitBasis.env's): its
     structures by the codec env, which writes one as a reference where it
     may be, and fingerprints one so (fpChild); its origins in the sidecar *)
  val env =
    recordType ("env", "Env.env",
                record ("Env.Env", [field ("vals", Map (Type "valstatus")), field ("tys", Map (Type "tystatus")),
                                    field ("strs", Map (Leaf "env")), side ("origins", Map (Leaf "origin"))])
                  |> fingerprint (NONE, [FpField (Both, "vals"), FpField (Both, "tys"), FpField (Both, "strs")],
                                  [("origins", "where each binding was written: the sidecar, which no hash reads")])
                  |> sameness ([SameField "origins", SameField "vals", SameField "tys", SameField "strs"], []))

  (* a signature: its own type names, by their arity and equality and by
     their places where its environment names them *)
  val sigma =
    recordType ("sigma", "SigMatch.sigma",
                record ("", [field ("bound", List (Leaf "tycon")), field ("env", Leaf "env"), side ("origin", Leaf "origin")])
                  |> fingerprint (NONE, [FpText (Both, "fpBound (w, {bound})"), FpText (Both, "fpEnvInto (w, localsOf {bound}, {env})")],
                                  [("origin", "where it was written: the sidecar")]))
    |> noSame

  (* a functor compiled to a function: its signature and the global of its
     function (UnitBasis.funcode); its fingerprint is fpFunctor's, of its
     parameter's and its result's signatures together *)
  val funinfo =
    recordType ("funinfo", "Elaborate.funinfo",
                record ("Elaborate.FunInfo", [field ("param", Option (Leaf "string")), field ("paramSig", Leaf "paramSigma"),
                                              field ("summary", Leaf "summary"), side ("binding", Leaf "origin"),
                                              abi ("code", Leaf "stamp")]))
    |> noFp |> noSame

  (* a fixity directive: its fingerprint is its text (UnitBasis.fingerprint) *)
  val fixity =
    sum ("fixity", "Fixity.fixity",
         [nullary "Fixity.Nonfix", args ("Fixity.Infix", [field ("p", Leaf "nat")]), args ("Fixity.Infixr", [field ("p", Leaf "nat")])])
    |> noFp |> noSame

  (* an overloading: what it is is its binder's identity, so none has a
     fingerprint *)
  val impl =
    sum ("impl", "Overload.impl", [args ("Overload.Prim", [abi ("p", Leaf "string")]), args ("Overload.Global", [abi ("g", Leaf "stamp")])])
    |> tagIn Abi |> noFp |> noSame
  val literal =
    sum ("literal", "Overload.literal", [args ("Overload.Bits", [abi ("b", Leaf "int")]), args ("Overload.Via", [abi ("g", Leaf "stamp")])])
    |> tagIn Abi |> noFp |> noSame
  val overload =
    recordType ("overload", "Overload.entry",
                record ("", [field ("kind", Leaf "string"), field ("ops", Map (Type "impl")), field ("literal", Type "literal")]))
    |> noFp |> noSame

  (* where a binding was written, in the sidecar: a definition of another unit
     held by the key that outlasts its span (Held) is written as the place it
     had *)
  val origin =
    sum ("origin", "Env.origin",
         [nullary "Env.Unknown",
          record ("Env.Named", [field ("unit", Leaf "string"), field ("kind", Leaf "string"), field ("name", Leaf "string"),
                                field ("span", Type "span")]),
          args ("Env.Constrained", [field ("actual", Type "origin"), field ("spec", Type "origin")]),
          record ("Env.Held", [field ("unit", Leaf "string"), field ("key", Leaf "string"), field ("last", Type "origin")])
            |> writtenAs "last"])
    |> noFp |> noSame

  (* a place in a source: its file as its family names files, and a function
     of Mid told of each (MidCodec's line table of a copied body) *)
  val span =
    recordType ("span", "Source.span",
                record ("", [field ("file", Leaf "file"), field ("start", Leaf "nat"), field ("stop", Leaf "nat")]) |> noted "position")
    |> noFp |> noSame

  (* the types of the IRs, each type of Mid written once and then by its
     number (MidCodec), a basis's whole *)
  val irty =
    sum ("irty", "Ty.ty",
         [args ("Ty.Gen", [field ("i", Leaf "tvar")]) |> built "Ty.gen",
          args ("Ty.Var", [field ("i", Leaf "tvar")]) |> built "Ty.var",
          args ("Ty.Con", [field ("s", Leaf "tyname"), field ("n", Leaf "string"), field ("args", List (Type "irty"))]) |> built "Ty.con",
          args ("Ty.Tuple", [field ("ts", List (Type "irty"))]) |> built "Ty.tuple",
          args ("Ty.Arrow", [field ("a", Type "irty"), field ("b", Type "irty")]) |> built "Ty.arrow",
          nullary "Ty.ExnCon" |> built "Ty.exnCon"])
    |> viewed "Ty.view" |> noFp |> noSame

  (* ---- Mid ---- *)

  fun mid (name, sml, parts) = sum (name, sml, parts) |> noFp |> noSame
  fun midRecord (name, sml, p) = recordType (name, sml, p) |> noFp |> noSame

  val const =
    mid ("const", "Lambda.const",
         [args ("Lambda.CInt", [field ("i", Leaf "bigint")]), args ("Lambda.CWord", [field ("i", Leaf "bigint")]),
          args ("Lambda.CInt64", [field ("i", Leaf "bigint")]), args ("Lambda.CWord64", [field ("i", Leaf "bigint")]),
          args ("Lambda.CReal", [field ("s", Leaf "string")]), args ("Lambda.CString", [field ("s", Leaf "string")]),
          args ("Lambda.CChar", [field ("n", Leaf "nat")])])

  val scheme = Tuple [List (Leaf "tvar"), Type "irty"]
  val params = List (Tuple [Leaf "binder", Type "irty"])

  val frame = midRecord ("frame", "Mid.frame", record ("", [field ("name", Leaf "string"), field ("site", Option (Type "span"))]))

  val atom =
    mid ("atom", "Mid.atom",
         [args ("Mid.Var", [field ("x", Leaf "stamp"), field ("ts", List (Type "irty"))]),
          args ("Mid.Global", [field ("x", Leaf "stamp"), field ("ts", List (Type "irty"))]),
          args ("Mid.Const", [field ("c", Type "const"), field ("t", Type "irty")]),
          args ("Mid.Con0", [field ("tag", Leaf "nat"), field ("t", Type "irty")]),
          nullary "Mid.Unit"])

  val rhs =
    mid ("rhs", "Mid.rhs",
         [args ("Mid.Atom", [field ("a", Type "atom")]),
          args ("Mid.App", [field ("f", Type "atom"), field ("args", List (Type "atom"))]),
          args ("Mid.Prim", [field ("n", Leaf "string"), field ("t", Type "irty"), field ("args", List (Type "atom"))]),
          args ("Mid.Tuple", [field ("args", List (Type "atom"))]),
          args ("Mid.Select", [field ("i", Leaf "nat"), field ("a", Type "atom")]),
          args ("Mid.Con", [field ("tag", Leaf "nat"), field ("t", Type "irty"), field ("a", Type "atom")]),
          args ("Mid.Decon", [field ("tag", Leaf "nat"), field ("t", Type "irty"), field ("a", Type "atom")]),
          args ("Mid.ConTag", [field ("a", Type "atom")]),
          args ("Mid.NewExn", [field ("s", Leaf "string")]),
          args ("Mid.BuiltinExn", [field ("i", Leaf "int")]),
          args ("Mid.MkExn", [field ("a", Type "atom"), field ("b", Type "atom")]),
          args ("Mid.ExnCon", [field ("a", Type "atom")]),
          args ("Mid.ExnArg", [field ("t", Type "irty"), field ("a", Type "atom")]),
          args ("Mid.SetGlobal", [field ("g", Leaf "stamp"), field ("a", Type "atom")])])

  (* binder: a name the function binds (MidCodec.binders), its own, numbered
     from 0 as the writing meets them *)
  val exp =
    mid ("exp", "Mid.exp",
         [args ("Mid.Let", [field ("x", Leaf "binder"), field ("s", scheme), field ("r", Type "rhs"), field ("b", Type "exp")]),
          args ("Mid.Fun", [field ("fs", List (Type "fundef")), field ("b", Type "exp")]),
          args ("Mid.Join", [field ("j", Leaf "binder"), field ("ps", params), field ("b", Type "exp"), field ("sc", Type "exp")]),
          args ("Mid.Jump", [field ("j", Leaf "stamp"), field ("args", List (Type "atom"))]),
          args ("Mid.If", [field ("a", Type "atom"), field ("t", Type "exp"), field ("f", Type "exp")]),
          args ("Mid.Handle", [field ("b", Type "exp"), field ("x", Leaf "binder"), field ("h", Type "exp")]),
          args ("Mid.Raise", [field ("a", Type "atom")]),
          args ("Mid.Return", [field ("r", Type "rhs")]),
          args ("Mid.Mark", [field ("pos", Tuple [Type "span", List (Type "frame")]), field ("b", Type "exp")])])

  (* label: the name a person knows the function by (Mid.fundef) *)
  val fundef =
    midRecord ("fundef", "Mid.fundef",
               record ("", [field ("name", Leaf "binder"), field ("label", Option (Leaf "string")),
                            field ("tyvars", List (Leaf "tvar")), field ("params", params),
                            field ("result", Type "irty"), field ("body", Type "exp")]))

  (* a function a basis keeps: its name is a global, the caller's *)
  val topfun =
    fundef |> renamed ("topfun", "Mid.fundef")
           |> withParts (List.map (withFields (List.map (fn (f : Codec.field) =>
                                                           if #name f = "name" then field ("name", Leaf "global") else f))))

  val def =
    mid ("def", "Mid.def",
         [args ("Mid.Val", [field ("g", Leaf "stamp"), field ("s", scheme), field ("e", Type "exp")]),
          args ("Mid.Funs", [field ("fs", List (Type "fundef"))]),
          args ("Mid.Do", [field ("gs", List (Tuple [Leaf "stamp", scheme])), field ("e", Type "exp")])])

  val datatypeInfo =
    midRecord ("datatypeInfo", "MidCanon.datatypeInfo",
               record ("", [field ("params", List (Leaf "tvar")),
                            field ("cons", List (Tuple [Leaf "nat", Leaf "string", Option (Type "irty")]))]))

  (* a unit's Mid, with the datatypes its types name, the layouts a body
     fixed and the open datatypes *)
  val unitMid =
    midRecord ("unitMid", "MidCanon.unitMid",
               record ("", [field ("mid", List (Type "def")), field ("datatypes", List (Tuple [Leaf "tyname", Type "datatypeInfo"])),
                            field ("pins", List (Tuple [Leaf "tyname", List (Tuple [Leaf "nat", Option (Leaf "nat")])])),
                            field ("opens", List (Leaf "tyname"))]))

  val types = [tyfcn, coninfo, exninfo, valstatus, tystatus, env, sigma, funinfo, fixity, impl, literal, overload, origin, span, irty,
               const, frame, atom, rhs, exp, fundef, topfun, def, datatypeInfo, unitMid]

  (* ---- the families ---- *)

  fun leaf (write, read, same, fp, key, layers) : leaf =
    {write = write, read = read, same = same, fp = fp, key = key, layers = layers, default = "", other = "", static = true}
  (* the leaf's other values for the fingerprint oracle, and whether its
     fingerprint is the static layer's *)
  fun others (other, static) ({write, read, same, fp, key, layers, default, ...} : leaf) : leaf =
    {write = write, read = read, same = same, fp = fp, key = key, layers = layers, default = default, other = other, static = static}
  val any = [Static, Abi, Side]
  (* a codec of Pickle's, and its key (CodecEmit.keyExp) *)
  fun keyOf w =
    case w of
      "string" => "Int.toString (size {x}) ^ \":\" ^ {x}"
    | "bool" => "(if {x} then \"+\" else \"-\")"
    | _ => "Int.toString {x} ^ \";\""
  fun pickled (w, r, fp) = leaf ("P." ^ w ^ " ({w}, {x})", "P." ^ r ^ " ({r})", "{x} = {y}", fp, keyOf w, any)

  val basis : family =
    {name = "basis",
     wparam = "e : enc", warg = "e", wstream = fn Static => "#w e" | Abi => "#a e" | Side => "#side e",
     rparam = "d : dec", rarg = "d", rstream = fn Static => "#r d" | Abi => "#a d" | Side => "#side d",
     fpparam = "w : P.writer, local' : int IntMap.map", fparg = "w, local'",
     static = "!staticLayer", side = "#side d",
     once = "once (#{t} {e}, #n{t} {e}, {w}, {key}, fn () => {body})",
     ronce = "ronce ({r}, #{t} {d}, #n{t} {d}, fn () => {body})",
     bad = "P.Bad", binder = NONE,
     leaves =
       [("bool", pickled ("bool", "rbool", "P.bool (w, {x})") |> others ("[not {x}]", true)),
        ("string", pickled ("string", "rstring", "P.string (w, {x})") |> others ("[{x} ^ \"'\"]", true)),
        ("nat", pickled ("nat", "rnat", "P.nat (w, {x})") |> others ("[{x} + 1]", true)),
        ("int", pickled ("int", "rint", "P.int (w, {x})") |> others ("[{x} + 1]", true)),
        (* a type, its parts written once (keyedTy), its variables numbered
           by first occurrence in a fingerprint (fpTy) *)
        ("ty", leaf ("ty ({e}, {x})", "rty {d}", "sameType ({x}, {y})", "fpTy (w, ref [], local', {x})", "", [Static])
               |> others ("otherTypes {x}", true)),
        (* a type name, its record written once *)
        ("tycon", leaf ("tycon ({e}, {x})", "rtycon {d}", "#stamp {x} = #stamp {y}", "fpTyconRef (w, local', {x})", "", [Static])
                  |> others ("[otherTycon {x}]", true)),
        (* names: built in, the unit's own, or an import (nameTo); a value by
           its anchor in a fingerprint *)
        ("stamp", leaf ("nameTo ({w}, {e}, kStamp, {x})", "rnameAt ({r}, {d}, kStamp)", "{x} = {y}", "fpAnchored (w, {x})", "", [Static, Abi])
                  |> others ("[{x} + 1]", false)),
        ("tvar", leaf ("nameTo ({w}, {e}, kTvar, {x})", "rnameAt ({r}, {d}, kTvar)", "{x} = {y}", "", "", [Static, Abi])
                 |> others ("[{x} + 1]", true)),
        ("tyname", leaf ("nameTo ({w}, {e}, kTycon, {x})", "rnameAt ({r}, {d}, kTycon)", "{x} = {y}", "", "", [Static, Abi])
                   |> others ("[{x} + 1]", true)),
        (* a binding's origin, in the sidecar (writeOrigin notes that one was) *)
        ("origin", {write = "writeOrigin ({e}, {x})", read = "ownOrigin (readOrigin' {r})", same = "{x} = {y}", fp = "", key = "",
                    layers = [Side], default = "Env.Unknown", other = "[otherOrigin {x}]", static = true}),
        (* an environment: whole, or a reference to a signature's structure
           (env, renv); in a fingerprint a child (fpChild) *)
        ("env", leaf ("env ({e}, {x})", "renv {d}", "sameEnv ({x}, {y})", "fpChild (w, local', {x})", "", [Static])),
        (* a functor's parameter and result, written where the structures of
           the parameter are those the result may refer to *)
        ("paramSigma", leaf ("paramSigma ({e}, {x})", "rsigma {d}", "", "", "", [Static])),
        ("summary", leaf ("summarySigma ({e}, {x})", "rsummary {d}", "", "", "", [Static]))],
     notes = [("position", "")]}

  val plain : family =
    {name = "plain",
     wparam = "w : P.writer", warg = "w", wstream = fn _ => "w",
     rparam = "r : P.reader", rarg = "r", rstream = fn _ => "r",
     fpparam = "", fparg = "", static = "", side = "", once = "", ronce = "",
     bad = "P.Bad", binder = NONE,
     leaves = [("string", pickled ("string", "rstring", "")), ("nat", pickled ("nat", "rnat", "")),
               ("file", pickled ("string", "rstring", ""))],
     notes = [("position", "")]}

  (* a function of Mid: every name by the caller's hooks (MidCodec.wctx,
     rctx) *)
  fun hook n = leaf ("#" ^ n ^ " {e} {x}", "#" ^ n ^ " {d} ()", "", "", "", any)
  val mid : family =
    {name = "mid",
     wparam = "c : wctx", warg = "c", wstream = fn _ => "#w c",
     rparam = "c : rctx", rarg = "c", rstream = fn _ => "#r c",
     fpparam = "", fparg = "", static = "", side = "", once = "", ronce = "",
     bad = "Bad", binder = SOME "binder",
     leaves = [("stamp", hook "stamp"), ("binder", hook "stamp"), ("global", hook "global"), ("tyname", hook "tycon"),
               ("tvar", hook "tvar"), ("file", hook "file"),
               ("string", pickled ("string", "rstring", "")), ("nat", pickled ("nat", "rnat", "")),
               ("int", pickled ("int", "rint", "")),
               ("bigint", leaf ("P.string ({w}, IntInf.toString {x})", "bigint {d}", "", "", "", any))],
     notes = [("position", "#position {e} {x}")]}

  (* ---- what is generated, and where ---- *)

  fun inst (family, ty, names, bad) : instance = {family = family, ty = ty, names = names, share = NONE, bad = bad}
  val instances =
    [inst ("basis", "tyfcn", [(Write, "tyfcn"), (Read, "rtyfcn"), (Same, "sameTyfcn"), (Fp, "fpFcn"), (Perturb, "perturbTyfcn")], "not a type function"),
     inst ("basis", "coninfo", [(Write, "coninfo"), (Read, "rconinfo"), (Same, "sameConinfo"), (Fp, "fpConinfo"), (Key, "keyConinfo"), (Perturb, "perturbConinfo")], ""),
     inst ("basis", "exninfo", [(Write, "exninfo"), (Read, "rexninfo"), (Same, "sameExninfo"), (Fp, "fpExninfo"), (Perturb, "perturbExninfo")], ""),
     inst ("basis", "valstatus", [(Write, "valstatus"), (Read, "rvalstatus"), (Same, "sameVal"), (Fp, "fpVal"), (Perturb, "perturbVal")], "not a value's status"),
     inst ("basis", "tystatus", [(Write, "tystatus"), (Read, "rtystatus"), (Same, "sameTy"), (Fp, "fpTyStr"), (Perturb, "perturbTy")], ""),
     inst ("basis", "env", [(Write, "envWhole"), (Read, "renvWhole"), (Same, "sameEnv"), (Fp, "fpEnvInto"), (Perturb, "perturbEnv")], ""),
     inst ("basis", "sigma", [(Write, "sigma"), (Read, "rsigma"), (Fp, "fpSigmaInto")], ""),
     inst ("basis", "funinfo", [(Write, "funinfo"), (Read, "rfuninfo")], ""),
     inst ("plain", "fixity", [(Write, "writeFixity"), (Read, "readFixity")], "not a fixity"),
     inst ("basis", "impl", [(Write, "impl"), (Read, "rimpl")], "not an operator"),
     inst ("basis", "literal", [(Write, "literal"), (Read, "rliteral")], "not a literal"),
     inst ("basis", "overload", [(Write, "overloadEntry"), (Read, "roverloadEntry")], ""),
     inst ("basis", "irty", [(Write, "irTy"), (Read, "rirTy")], "not a type of the IRs"),
     inst ("plain", "origin", [(Write, "writeOrigin'"), (Read, "readOrigin'")], "invalid binding origin"),
     inst ("plain", "span", [(Write, "writeSpan"), (Read, "readSpan")], ""),
     inst ("mid", "const", [(Write, "const"), (Read, "rconst")], "not a constant"),
     {family = "mid", ty = "irty", names = [(Write, "ty"), (Read, "rty")],
      share = SOME {tag = 6, id = "Ty.id", table = "#written {e}", count = "#nwritten {e}", rtable = "#read' {d}", rcount = "#nread {d}"},
      bad = "not a type"},
     inst ("mid", "span", [(Write, "span"), (Read, "rspan")], ""),
     inst ("mid", "frame", [(Write, "frame"), (Read, "rframe")], ""),
     inst ("mid", "atom", [(Write, "atom"), (Read, "ratom")], "not an atom"),
     inst ("mid", "rhs", [(Write, "rhs"), (Read, "rrhs")], "not a step"),
     inst ("mid", "exp", [(Write, "exp"), (Read, "rexp"), (Binds, "bindsExp")], "not an expression"),
     inst ("mid", "fundef", [(Write, "fundef"), (Read, "rfundef"), (Binds, "bindsFundef")], ""),
     inst ("mid", "topfun", [(Write, "topfun"), (Read, "rtopfun"), (Binds, "bindsTopfun")], ""),
     inst ("mid", "def", [(Write, "def"), (Read, "rdef")], "not a definition"),
     inst ("mid", "datatypeInfo", [(Write, "datatypeInfo"), (Read, "rdatatypeInfo")], ""),
     inst ("mid", "unitMid", [(Write, "unitMid"), (Read, "runitMid")], "")]

  val ub = "lib/compiler/driver/unitbasis.sml"
  fun region (file, name, start, items) : region = {file = file, name = name, start = start, items = items}
  fun all (fam, tr) = List.map (fn t => (fam, t, tr))
  val regions =
    [region (ub, "fingerprints of values and types", "and",
             all ("basis", Fp) ["tyfcn", "valstatus", "coninfo", "exninfo", "tystatus"]),
     region (ub, "fingerprints of environments", "fun", all ("basis", Fp) ["env"]),
     region (ub, "fingerprints of signatures", "fun", all ("basis", Fp) ["sigma"]),
     region (ub, "writers of values and types", "fun",
             all ("basis", Write) ["tyfcn", "irty", "coninfo"] @ [("basis", "coninfo", Key)]
             @ all ("basis", Write) ["exninfo", "valstatus", "tystatus"]),
     region (ub, "writers of origins", "fun", all ("plain", Write) ["origin", "span", "fixity"]),
     region (ub, "writers of environments", "and", all ("basis", Write) ["env", "sigma"]),
     region (ub, "writers of functors", "fun", all ("basis", Write) ["funinfo"]),
     region (ub, "samenesses", "fun", all ("basis", Same) ["tyfcn", "coninfo", "exninfo", "valstatus", "tystatus", "env"]),
     region (ub, "changes for the fingerprint oracle", "fun", all ("basis", Perturb) ["tyfcn", "coninfo", "exninfo", "valstatus", "tystatus", "env"]),
     region (ub, "writers of overloading", "fun", all ("basis", Write) ["impl", "literal", "overload"]),
     region (ub, "readers of values and types", "fun", all ("basis", Read) ["tyfcn", "irty", "coninfo", "exninfo", "valstatus", "tystatus"]),
     region (ub, "readers of origins", "fun", all ("plain", Read) ["origin", "span", "fixity"]),
     region (ub, "readers of environments", "and", all ("basis", Read) ["env", "sigma"]),
     region (ub, "readers of functors and overloading", "fun", all ("basis", Read) ["funinfo", "impl", "literal", "overload"]),
     region ("lib/compiler/core/midcodec.sml", "codecs of Mid", "fun",
             all ("mid", Write) ["const", "irty", "span", "frame", "atom", "rhs", "exp", "fundef", "topfun", "def"]
             @ all ("mid", Read) ["const", "irty", "span", "frame", "atom", "rhs", "exp", "fundef", "topfun", "def"]
             @ all ("mid", Binds) ["exp", "fundef", "topfun"]),
     region ("lib/compiler/driver/unitmid.sml", "codecs of a unit's Mid", "fun",
             all ("mid", Write) ["datatypeInfo", "unitMid"] @ all ("mid", Read) ["datatypeInfo", "unitMid"])]

  val description : description = {types = types, families = [basis, plain, mid], instances = instances, regions = regions}
end
