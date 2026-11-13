(* libraries: test/unit *)
(* HsIface (the haskell98 roadmap's M21d): a unit's interface written and
   read back, every form of a module's interface among it: kinds, a kind
   and a type variable linked (written as what they are linked to), types,
   schemes with contexts, a synonym, a class, an instance, a constructor, a
   field, a method, a definition with its parent, a fixity; and a string
   with spaces and colons in it. What is read writes the same text again,
   and stands for what a client reads alike (HsModIface.canonical). *)
structure HsIfaceTests =
struct
  structure T = HsTypes
  structure Mo = HsModules

  fun need (ok, message) = Expect.that (message, ok)

  val starToStar = T.KFun (T.KStar, T.KStar)
  val linkedKind = T.KVar (ref (T.KLink starToStar))
  val a = T.TGen 0
  val listOf = T.TAp (T.TCon "[]", a)
  val linkedTy = T.TMeta (ref (T.Link (T.TCon "Int")))
  fun e (sp, n) = {space = sp, home = "M", name = n} : Mo.entity

  val iface : HsModIface.t =
    {id = "M",
     exports = [e (Mo.Value, "f"), e (Mo.Type, "T"), e (Mo.Value, "a name: with spaces")],
     defs = [{entity = e (Mo.Type, "T"), sort = Mo.TyCon, parent = NONE, arity = 0, span = {file = "M.hs", start = 1, stop = 9}},
             {entity = e (Mo.Value, "MkT"), sort = Mo.Con, parent = SOME (e (Mo.Type, "T")), arity = 1,
              span = {file = "M.hs", start = 10, stop = 14}}],
     fixities = [("v M +++", (HsAst.Infixr, 5)), ("v M <<", (HsAst.Infixl, 9))],
     checked =
       {values = [("v M f", {vars = 1, ctx = [{cls = "t M C", ty = a}], ty = T.TAp (T.TAp (T.TCon "->", a), listOf)}),
                  ("v M g", {vars = 0, ctx = [], ty = linkedTy})],
        tycons = [{key = "t M T", kind = linkedKind, params = 1, synonym = NONE, cons = ["v M MkT"], newtype = true},
                  {key = "t M S", kind = T.KStar, params = 0, synonym = SOME (T.TAp (T.TCon "t M T", T.TCon "Int")),
                   cons = [], newtype = false}],
        classes = [{key = "t M C", supers = ["t Prelude Eq"], methods = ["v M m"], kind = T.KStar}],
        instances = [{id = "t M C@t M T", cls = "t M C", tycon = "t M T", vars = 1, ctx = [{cls = "t M C", ty = a}],
                      derived = false, home = "M"}],
        cons = [("v M MkT", {tycon = "t M T", arity = 1, fields = ["v M unT"]})],
        fields = [("v M unT", {tycon = "t M T", ty = a, cons = [("v M MkT", 0)]})],
        methods = [("v M m", {cls = "t M C", scheme = {vars = 1, ctx = [], ty = T.TAp (T.TAp (T.TCon "->", a), a)}})]}}

  fun roundTrip () =
    let
      val text = HsIface.encodeModule iface
      val back = HsIface.decodeModule text
      val () = need (HsIface.encodeModule back = text, "what is read writes the same text again")
      val () = need (HsModIface.canonical back = HsModIface.canonical iface, "and stands for what the interface stood for")
      val () = need (#exports back = #exports iface andalso #defs back = #defs iface andalso #fixities back = #fixities iface,
                     "its exports, definitions and fixities as they were")
      val whole = {modules = [iface, back], desugar = "the desugaring's part\nof two lines", unfoldings = []}
      val again = HsIface.decode (HsIface.encode whole)
      val () = need (HsIface.encode again = HsIface.encode whole andalso #desugar again = #desugar whole
                     andalso length (#modules again) = 2, "a unit's interface read back as written")
    in () end

  fun refused () =
    let
      fun refuses s = (ignore (HsIface.decode s); false) handle HsIface.Bad _ => true
      val text = HsIface.encode {modules = [iface], desugar = "", unfoldings = []}
      val () = need (refuses (String.substring (text, 0, size text - 3)), "a text cut short is refused")
      val () = need (refuses ("9:NotIfaces 1 0 0: 0 "), "a text of another mark is refused")
      val unsolved = {id = "M", exports = [], defs = [], fixities = [],
                      checked = {values = [("v M h", {vars = 0, ctx = [], ty = T.TMeta (ref (T.Free {id = 7, level = 0, home = "M"}))})],
                                 tycons = [], classes = [], instances = [], cons = [], fields = [], methods = []}}
      val () = need ((ignore (HsIface.encodeModule unsolved); false) handle HsIface.Bad _ => true,
                     "an unsolved type variable is no interface's")
    in () end
end

structure HsIfaceTestMain = Main (struct
  val name = "language-haskell-hsiface"
  val tests = Test.describe "hsiface" [Test.it "round trip" HsIfaceTests.roundTrip, Test.it "refused" HsIfaceTests.refused]
end)
val () = HsIfaceTestMain.main ()
