(* rhc's library (the haskell98 roadmap's D36, D37): the Report's 20 modules
   in share/rhc/haskell98, in the Report's own layout, which `--share DIR`
   names (the wrapper bin/rhc gives it), what of it a program cannot
   import, and the two modules the Report names and never defines.

   Interim, until the overlay's entries are written (M17, M18; L tells F
   in impl/progress/f.md when a rule can go): the Report's illustrations
   are read as E16 read them (results/E16/norm_libs.py), so that the
   modules parse and their names resolve, each rule keeping the line it is
   on, so that a diagnostic of the library points at the Report's text.
   Each rule, and the entries of share/rhc/haskell98/overlay.tsv that
   replace it:

   - I1. The built-in types' `data` lines are the instances their
     `deriving` clauses name: ov.prelude.unit, ov.prelude.list,
     ov.prelude.tuples.
   - I2. An instance whose body is `...` has an empty body:
     ov.prelude.int, ov.prelude.integer, ov.prelude.float,
     ov.prelude.double, ov.preludeio.ioerror, ov.directory.permissions,
     ov.time.clocktime, ov.random.stdgen, ov.random.instances.
   - I3. A type whose constructors are elided or not given is
     `data T = PrimT`: ov.prelude.char, ov.prelude.io, ov.prelude.int,
     ov.prelude.integer, ov.prelude.float, ov.prelude.double,
     ov.preludeio.ioerror, ov.time.clocktime, ov.random.stdgen.
   - I4. `= ...` is `= primElided`: ov.prelude.seq, ov.prelude.io,
     ov.time.functions, ov.time.decodes.
   - I5. A signature with no binding is a primitive's, `x = primElided`:
     ov.directory.prims (and ov.io.handles, ov.cputime.prims,
     ov.system.prims, ov.random.global, where their names are so given).
   - I6. A module that names primElided imports it from PreludeBuiltin:
     goes with I4 and I5.
   - I7. PreludeBuiltin and UnicodePrims are no files: they are rhc's
     runtime in Core (CoreRuntime), and export the names of the primitives
     the library uses, with primElided; this is the library's form, not an
     interim one (L, M17).
   - I8. Every primitive has the type `forall a. a` (E16 typed the
     library so): the overlay's entries of I4, I5 and I7, which type them.

   A program's own module of any of these names is the program's: a
   module of the library has the identity `haskell98:` and its name. *)
structure RhcLibrary =
struct
  (* the library's name, the prefix of its modules' identities *)
  val name = "haskell98"

  (* where the library is: --share's DIR *)
  val share : string option ref = ref NONE

  fun identity m = name ^ ":" ^ m

  fun dir () = Option.map (fn d => OS.Path.concat (d, name)) (!share)

  (* the modules a program cannot import: the three the Prelude is made of
     (chapter 8, D36), rhc's two of primitives, and rhc's own two of the
     library, PreludeRuntime and PreludeEnum (M17) *)
  val hidden = ["PreludeList", "PreludeText", "PreludeIO", "PreludeBuiltin", "UnicodePrims", "PreludeRuntime", "PreludeEnum"]

  fun isHidden m = List.exists (fn h => h = m) hidden

  (* the modules no file holds, and what they export *)
  val leaves =
    [("PreludeBuiltin",
      ["primAppendFile", "primCatch", "primCharToInt", "primElided", "primError", "primGetChar", "primGetContents",
       "primIOError", "primIntToChar", "primPutChar", "primReadFile", "primUserError", "primWriteFile"]),
     ("UnicodePrims",
      ["primUnicodeIsAlphaNum", "primUnicodeIsLower", "primUnicodeIsPrint", "primUnicodeIsUpper",
       "primUnicodeMaxChar", "primUnicodeToLower", "primUnicodeToUpper"])]

  fun isLeaf m = List.exists (fn (l, _) => l = m) leaves

  (* ---- the Report's illustrations, read until M17 ---- *)

  fun dropSpace s = Substring.string (Substring.dropl Char.isSpace (Substring.full s))
  fun trimRight s = Substring.string (Substring.dropr Char.isSpace (Substring.full s))
  fun words s = String.tokens Char.isSpace s
  fun isIdChar c = Char.isAlphaNum c orelse c = #"_" orelse c = #"'"

  (* the index of the first `p` in `s` at or after `i` *)
  fun find (s, p, i) =
    if i + size p > size s then NONE
    else if String.substring (s, i, size p) = p then SOME i
    else find (s, p, i + 1)

  fun findLast (s, p) =
    let fun go (i, last) = case find (s, p, i) of SOME j => go (j + 1, SOME j) | NONE => last
    in go (0, NONE) end

  (* the built-in types' lines: the instances their deriving clauses name *)
  val builtins =
    [("data () = () deriving (Eq, Ord, Enum, Bounded)",
      "instance Eq (); instance Ord (); instance Enum (); instance Bounded ()"),
     ("data [a] = [] | a : [a] deriving (Eq, Ord)", "instance Eq a => Eq [a]; instance Ord a => Ord [a]"),
     ("data (a,b) = (a,b) deriving (Eq, Ord, Bounded)",
      "instance (Eq a, Eq b) => Eq (a,b); instance (Ord a, Ord b) => Ord (a,b); \
      \instance (Bounded a, Bounded b) => Bounded (a,b)"),
     ("data (a,b,c) = (a,b,c) deriving (Eq, Ord, Bounded)",
      "instance (Eq a, Eq b, Eq c) => Eq (a,b,c); instance (Ord a, Ord b, Ord c) => Ord (a,b,c); \
      \instance (Bounded a, Bounded b, Bounded c) => Bounded (a,b,c)")]

  (* `instance ... where ...`: the body left out *)
  fun elidedInstance line =
    if not (String.isPrefix "instance" line) then NONE
    else
      case findLast (line, "where") of
        NONE => NONE
      | SOME i =>
          let val rest = dropSpace (String.extract (line, i + 5, NONE))
          in
            if String.isPrefix ".." rest then
              let val after = dropSpace (String.extract (rest, if String.isPrefix "..." rest then 3 else 2, NONE))
              in if after = "" orelse String.isPrefix "--" after then SOME (String.substring (line, 0, i + 5)) else NONE end
            else NONE
          end

  (* `data T a = ...`, or `data T` with no constructors: one of its own *)
  fun elidedData line =
    if not (String.isPrefix "data" line) orelse size line < 5 orelse not (Char.isSpace (String.sub (line, 4))) then NONE
    else
      let
        val s = Substring.dropl Char.isSpace (Substring.extract (line, 4, NONE))
        val (tycon, rest) = Substring.splitl isIdChar s
        fun vars (r, acc) =
          let
            val r' = Substring.dropl Char.isSpace r
            val (v, more) = Substring.splitl isIdChar r'
          in
            if Substring.size v > 0 andalso Char.isLower (Substring.sub (v, 0)) then vars (more, Substring.string v :: acc)
            else (List.rev acc, Substring.string r')
          end
        val (vs, after) = vars (rest, [])
        val t = Substring.string tycon
        val hasDots = isSome (find (line, "...", 0))
        val hasEq = isSome (find (line, "=", 0))
      in
        if t = "" orelse not (Char.isUpper (String.sub (t, 0))) then NONE
        else if (String.isPrefix "=" after andalso hasDots) orelse ((after = "" orelse String.isPrefix "--" after) andalso not hasEq)
        then SOME (String.concatWith " " ("data" :: t :: vs) ^ " = Prim" ^ t)
        else NONE
      end

  (* `= ...`: a primitive's value *)
  fun elidedValue line =
    let
      fun go (i, acc, changed) =
        if i >= size line then (String.concat (List.rev acc), changed)
        else if String.sub (line, i) = #"=" then
          let
            fun skip j = if j < size line andalso Char.isSpace (String.sub (line, j)) then skip (j + 1) else j
            val j = skip (i + 1)
          in
            if j + 3 <= size line andalso String.substring (line, j, 3) = "..." then go (j + 3, "= primElided" :: acc, true)
            else go (i + 1, "=" :: acc, changed)
          end
        else go (i + 1, str (String.sub (line, i)) :: acc, changed)
      val (out, changed) = go (0, [], false)
    in
      if changed then SOME out else NONE
    end

  fun normaliseLine line =
    let val flat = String.concatWith " " (words line)
    in
      case List.find (fn (b, _) => String.isPrefix b flat) builtins of
        SOME (_, instances) => instances
      | NONE =>
          case elidedInstance line of
            SOME l => l
          | NONE =>
              case elidedData line of
                SOME l => l
              | NONE => getOpt (elidedValue line, line)
    end

  (* `normalise bytes` is a module of the library with its illustrations
     read as code, line for line *)
  fun normalise bytes = String.concatWith "\n" (List.map normaliseLine (String.fields (fn c => c = #"\n") bytes))

  fun mentionsElided text = isSome (find (text, "primElided", 0))

  (* ---- the module, read ---- *)

  structure A = HsAst

  fun nameOf (A.Name (_, {name, ...})) = name

  (* A signature with no binding is a primitive's, `x = primElided`; and
     a module that names primElided, in its text (`elidedText`) or so,
     and does not import PreludeBuiltin imports it. *)
  fun primitives (A.Module (a, {name = n, exports, imports, decls}), elidedText : bool) =
    let
      fun bound (A.D (_, x)) =
        case x of
          A.DFun (f, _) => [nameOf (funName f)]
        | A.DPat (p, _) => List.map nameOf (patVars p)
        | _ => []
      and funName (A.F (_, x)) =
        case x of
          A.FPrefix (v, _) => v
        | A.FInfix (_, A.VarOp v, _) => v
        | A.FInfix (_, A.ConOp v, _) => v
        | A.FParen (l, _) => funName l
      and patVars (A.P (_, x)) =
        case x of
          A.PVar v => [v]
        | A.PParen p => patVars p
        | A.PTuple ps => List.concat (List.map patVars ps)
        | _ => []
      val names = List.concat (List.map bound decls)
      val unbound =
        List.concat (List.map (fn A.D (_, A.DSig (vs, _, _)) =>
                                    List.filter (fn v => not (List.exists (fn m => m = nameOf v) names)) vs
                                | _ => []) decls)
      fun var s = A.Name (A.noAnn, {qual = "", name = s})
      val elided = A.E (A.noAnn, A.EVar (var "primElided"))
      val added = List.map (fn v => A.D (A.noAnn, A.DPat (A.P (A.noAnn, A.PVar v), A.Rhs (A.noAnn, A.Plain (elided, NONE))))) unbound
      val importsBuiltin = List.exists (fn A.Import (_, {module = m, ...}) => nameOf m = "PreludeBuiltin") imports
      val extra =
        if importsBuiltin orelse not (elidedText orelse not (null unbound)) then []
        else [A.Import (A.noAnn, {qualified = false, module = var "PreludeBuiltin", as_ = NONE, hiding = false,
                                  spec = SOME [A.Ent (A.noAnn, A.EntVar (var "primElided"))]})]
    in
      A.Module (a, {name = n, exports = exports, imports = imports @ extra, decls = decls @ added})
    end
end
