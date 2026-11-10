(* The syntax generator of the haskell98 roadmap's D55: random trees of
   Haskell 98's abstract syntax, drawn by the productions of the Report's
   section 9.5 and with no annotations, so that the explicit and the
   implicit print of each can be read back and compared with it. A tree is
   drawn as the parser would make it of its print: an operand that reaches
   to the right only last in a sequence, parentheses where a production
   wants an atom, `[]` and `()` as constructors. It needs no type checker,
   and reaches what a corpus never writes. *)
structure SyntaxGen =
struct
  structure A = HsAst

  (* ---- a generator of numbers: Park and Miller's, from a seed ---- *)

  val state = ref 1

  fun seed n = state := (n mod 2147483646) + 1

  fun next () = (state := (!state * 48271) mod 2147483647; !state)

  (* a number from 0 to n - 1 *)
  fun below n = next () mod n

  fun chance (k, n) = below n < k

  fun pick xs = List.nth (xs, below (length xs))

  (* one of the choices, by their weights *)
  fun oneOf (choices : (int * (unit -> 'a)) list) : 'a =
    let
      val total = List.foldl (fn ((w, _), s) => w + s) 0 choices
      fun go (k, (w, f) :: r) = if k < w then f () else go (k - w, r)
        | go (_, []) = raise Fail "oneOf"
    in
      go (below total, choices)
    end

  fun several (lo, hi, f) = List.tabulate (lo + below (hi - lo + 1), fn _ => f ())

  (* ---- names and literals ---- *)

  val noAnn = A.noAnn

  fun name (q, n) = A.Name (noAnn, {qual = q, name = n})
  fun plainName n = name ("", n)

  val varNames = ["x", "y", "f", "go", "xs'", "a1", "_u", "z9"]
  val conNames = ["Just", "Nothing", "T", "K", "Pair"]
  val varSyms = ["+", "<>", "*", "$", ".", "&&", ">>=", "!", "-"]
  val conSyms = [":+", ":|", "::="]
  val tyVars = ["a", "b", "m", "t"]
  val tyCons = ["Int", "Maybe", "T", "Either"]
  val classes = ["Eq", "Show", "Monad", "C"]

  fun var () = plainName (pick varNames)
  fun qvar () = if chance (1, 6) then name ("M", pick varNames) else var ()
  fun con () = if chance (1, 8) then plainName (pick conSyms) else plainName (pick conNames)
  fun qcon () =
    oneOf [(6, con), (1, fn () => name ("M", pick conNames)),
           (1, fn () => plainName (pick ["()", "[]", "(,)", "(,,)"]))]
  fun tyvar () = plainName (pick tyVars)

  fun varOp () =
    oneOf [(4, fn () => A.VarOp (plainName (pick varSyms))),
           (1, fn () => A.VarOp (plainName (pick ["div", "elem", "on"]))),
           (1, fn () => A.VarOp (name ("M", "+")))]
  fun conOp () =
    oneOf [(3, fn () => A.ConOp (plainName ":")), (2, fn () => A.ConOp (plainName (pick conSyms))),
           (1, fn () => A.ConOp (plainName "K")), (1, fn () => A.ConOp (name ("M", ":+")))]
  fun anyOp () = if chance (2, 3) then varOp () else conOp ()
  (* an operator with no qualifier, which a definition or a fixity names *)
  fun ownVarOp () = A.VarOp (plainName (pick (["div", "elem"] @ List.filter (fn s => s <> "-") varSyms)))
  fun ownConOp () = A.ConOp (plainName (pick (conSyms @ ["K"])))

  (* literals, each with the value the lexer gives its text *)
  fun lit () =
    A.Lit (noAnn,
      oneOf [(3, fn () => let val n = below 1000 in A.LInt (IntInf.fromInt n, Int.toString n) end),
             (1, fn () => pick [A.LInt (IntInf.fromInt 31, "0x1F"), A.LInt (IntInf.fromInt 15, "0o17"),
                                A.LInt (IntInf.fromInt 255, "0XfF")]),
             (1, fn () => A.LFloat (pick ["1.5", "2e3", "1.0e-2", "3.25E+1"])),
             (2, fn () => pick [A.LChar (97, "'a'"), A.LChar (10, "'\\n'"), A.LChar (39, "'\\''"),
                                A.LChar (1, "'\\SOH'"), A.LChar (32, "' '")]),
             (2, fn () => pick [A.LString ([], "\"\""), A.LString ([104, 105], "\"hi\""),
                                A.LString ([97, 10, 98], "\"a\\nb\""), A.LString ([34], "\"\\\"\""),
                                A.LString ([45, 45], "\"--\"")])])
  fun numLit () =
    A.Lit (noAnn, if chance (3, 4) then let val n = below 100 in A.LInt (IntInf.fromInt n, Int.toString n) end
                  else A.LFloat "2.5")

  (* ---- types ---- *)

  fun T x = A.T (noAnn, x)

  fun ty d : A.ty =
    if d > 0 andalso chance (1, 4) then T (A.TFun (btype (d - 1), ty (d - 1))) else btype d

  and btype d =
    if d > 0 andalso chance (1, 3) then
      List.foldl (fn (a, f) => T (A.TApp (f, a))) (atype (d - 1)) (several (1, 2, fn () => atype (d - 1)))
    else atype d

  and atype d =
    if d <= 0 then oneOf [(2, fn () => T (A.TVar (tyvar ()))), (2, fn () => T (A.TCon (plainName (pick tyCons))))]
    else
      oneOf [(3, fn () => T (A.TVar (tyvar ()))),
             (3, fn () => T (A.TCon (if chance (1, 5) then name ("M", "T") else plainName (pick tyCons)))),
             (1, fn () => T (A.TCon (plainName (pick ["()", "[]", "(->)", "(,)"])))),
             (1, fn () => T (A.TList (ty (d - 1)))),
             (1, fn () => T (A.TTuple (several (2, 3, fn () => ty (d - 1))))),
             (1, fn () => T (A.TParen (ty (d - 1))))]

  (* a class assertion: C a, or, unless simple, C (a t ...) *)
  fun assertion simple =
    let val c = T (A.TCon (plainName (pick classes)))
    in
      if simple orelse chance (2, 3) then T (A.TApp (c, T (A.TVar (tyvar ()))))
      else
        T (A.TApp (c, T (A.TParen (List.foldl (fn (a, f) => T (A.TApp (f, a))) (T (A.TVar (tyvar ())))
                                              (several (1, 2, fn () => atype 1))))))
    end

  fun context simple : A.ty option =
    if chance (2, 3) then NONE
    else
      SOME (oneOf [(3, fn () => assertion simple),
                   (1, fn () => T (A.TParen (assertion simple))),
                   (1, fn () => T (A.TTuple (several (2, 3, fn () => assertion simple)))),
                   (1, fn () => T (A.TCon (plainName "()")))])

  (* ---- patterns ---- *)

  fun P x = A.P (noAnn, x)

  (* pat: n+k only where `nk` *)
  fun pat (d, nk) : A.pat =
    if nk andalso d > 0 andalso chance (1, 12) then
      P (A.PNPlusK (var (), A.Lit (noAnn, let val n = below 9 + 1 in A.LInt (IntInf.fromInt n, Int.toString n) end)))
    else if d > 0 andalso chance (1, 5) then
      P (A.PSeq (A.PA (operand (d - 1))
                 :: List.concat (several (1, 2, fn () => [A.PO (conOp ()), A.PA (operand (d - 1))]))))
    else operand d

  (* - literal, a constructor applied to atoms, or an atom *)
  and operand d =
    if chance (1, 10) then P (A.PNegLit (numLit ()))
    else if d > 0 andalso chance (1, 4) then P (A.PCon (qcon (), several (1, 3, fn () => apat (d - 1))))
    else apat d

  and apat d =
    if d <= 0 then oneOf [(3, fn () => P (A.PVar (var ()))), (1, fn () => P A.PWild),
                          (1, fn () => P (A.PCon (qcon (), []))), (1, fn () => P (A.PLit (lit ())))]
    else
      oneOf [(4, fn () => P (A.PVar (var ()))),
             (1, fn () => P A.PWild),
             (2, fn () => P (A.PCon (qcon (), []))),
             (1, fn () => P (A.PLit (lit ()))),
             (1, fn () => P (A.PAs (var (), apat (d - 1)))),
             (1, fn () => P (A.PLazy (apat (d - 1)))),
             (1, fn () => P (A.PParen (pat (d - 1, true)))),
             (1, fn () => P (A.PTuple (several (2, 3, fn () => pat (d - 1, true))))),
             (1, fn () => P (A.PList (several (1, 3, fn () => pat (d - 1, true))))),
             (1, fn () => P (A.PRec (plainName (pick conNames),
                                     several (0, 2, fn () => (qvar (), pat (d - 1, true))))))]

  (* ---- expressions and declarations ---- *)

  fun E x = A.E (noAnn, x)
  fun D x = A.D (noAnn, x)
  fun S x = A.S (noAnn, x)

  fun exp d : A.exp =
    if d > 0 andalso chance (1, 8) then E (A.ESig (opExpWith (d - 1, true), context false, ty 2)) else opExp d

  and opExp d = opExpWith (d, false)

  (* An operand, or a sequence of them with operators and negations, where
     an operand that reaches to the right comes last, and none does if
     `shut`: before `::` or the operator of a left section. *)
  and opExpWith (d, shut) =
    let fun final d = if shut then closed d else exp10 d
    in
      if d > 0 andalso chance (1, 3) then
        let
          val n = 1 + below 3
          fun item last =
            (if chance (1, 6) then [A.ENeg] else []) @ [A.EA (if last then final (d - 1) else closed (d - 1))]
          val items = List.concat (List.tabulate (n + 1, fn k =>
                        (if k > 0 then [A.EO (anyOp ())] else []) @ item (k = n)))
        in
          E (A.ESeq items)
        end
      else if chance (1, 8) then E (A.ESeq [A.ENeg, A.EA (final d)])
      else final d
    end

  (* an operand that does not reach to the right *)
  and closed d =
    if d > 0 andalso chance (1, 6) then
      oneOf [(1, fn () => E (A.ECase (exp (d - 1), several (1, 3, fn () => alt (d - 1))))),
             (1, fn () => E (A.EDo (stmts (d - 1))))]
    else fexp d

  and exp10 d =
    if d <= 0 then fexp d
    else
      oneOf [(6, fn () => fexp d),
             (1, fn () => E (A.ELam (several (1, 3, fn () => apat (d - 1)), exp (d - 1)))),
             (1, fn () => E (A.ELet (decls (d - 1), exp (d - 1)))),
             (1, fn () => E (A.EIf (exp (d - 1), exp (d - 1), exp (d - 1)))),
             (1, fn () => E (A.ECase (exp (d - 1), several (1, 3, fn () => alt (d - 1))))),
             (1, fn () => E (A.EDo (stmts (d - 1))))]

  and fexp d =
    if d > 0 andalso chance (1, 3) then
      List.foldl (fn (a, f) => E (A.EApp (f, a))) (aexp (d - 1)) (several (1, 3, fn () => aexp (d - 1)))
    else aexp d

  and fields d = several (1, 2, fn () => (qvar (), exp (d - 1)))

  and aexp d =
    if d <= 0 then oneOf [(3, fn () => E (A.EVar (qvar ()))), (1, fn () => E (A.ECon (qcon ()))),
                          (2, fn () => E (A.ELit (lit ())))]
    else
      oneOf [(4, fn () => E (A.EVar (qvar ()))),
             (1, fn () => E (A.EVar (plainName (pick varSyms)))),
             (2, fn () => E (A.ECon (qcon ()))),
             (2, fn () => E (A.ELit (lit ()))),
             (2, fn () => E (A.EParen (exp (d - 1)))),
             (1, fn () => E (A.ETuple (several (2, 3, fn () => exp (d - 1))))),
             (1, fn () => E (A.EList (several (1, 3, fn () => exp (d - 1))))),
             (1, fn () => E (A.EEnum (exp (d - 1), if chance (1, 2) then SOME (exp (d - 1)) else NONE,
                                      if chance (1, 2) then SOME (exp (d - 1)) else NONE))),
             (1, fn () => E (A.EComp (exp (d - 1), several (1, 3, fn () => qual (d - 1))))),
             (1, fn () => E (A.ELeftSec (opExpWith (d - 1, true), anyOp ()))),
             (1, fn () =>
                 let val o' = case anyOp () of A.VarOp (A.Name (_, {name = "-", ...})) => A.VarOp (plainName "+") | x => x
                 in E (A.ERightSec (o', opExp (d - 1))) end),
             (1, fn () => E (A.ERecCon (plainName (pick conNames), if chance (1, 3) then [] else fields d))),
             (1, fn () => E (A.ERecUpd (E (A.EVar (qvar ())), fields d)))]

  and qual d =
    oneOf [(2, fn () => S (A.SBind (pat (d, true), exp d))), (1, fn () => S (A.SLet (decls d))),
           (2, fn () => S (A.SExp (exp d)))]

  and stmts d =
    several (0, 2, fn () => qual d) @ [S (A.SExp (exp d))]

  and alt d = A.Alt (noAnn, pat (d, true), rhs (d, true))

  and rhs (d, inAlt) =
    A.Rhs (noAnn,
      if chance (1, 3) then
        (* before an alternative's `->`, a guard's type would go on *)
        A.Guarded (several (1, 2, fn () => A.Guard (noAnn, opExpWith (d, inAlt), exp d)), wheres d)
      else A.Plain (exp d, wheres d))

  and wheres d = if d > 0 andalso chance (1, 4) then SOME (decls (d - 1)) else NONE

  and funlhs d : A.funlhs =
    oneOf [(4, fn () => A.F (noAnn, A.FPrefix (var (), several (1, 3, fn () => apat d)))),
           (2, fn () => A.F (noAnn, A.FInfix (side d, ownVarOp (), side d))),
           (1, fn () => A.F (noAnn, A.FParen (A.F (noAnn, A.FInfix (side d, ownVarOp (), side d)),
                                               several (1, 2, fn () => apat d))))]

  (* a side of an infix left-hand side: a pattern with no variable operator *)
  and side d =
    if d > 0 andalso chance (1, 4) then P (A.PSeq [A.PA (operand (d - 1)), A.PO (conOp ()), A.PA (operand (d - 1))])
    else operand d

  and fixityDecl () =
    D (A.DFixity (pick [A.Infix, A.Infixl, A.Infixr],
                  if chance (2, 3) then SOME (A.Lit (noAnn, let val n = below 10 in A.LInt (IntInf.fromInt n, Int.toString n) end))
                  else NONE,
                  several (1, 2, fn () => if chance (2, 3) then ownVarOp () else ownConOp ())))

  and sigDecl () = D (A.DSig (several (1, 2, fn () => if chance (1, 5) then plainName "+" else var ()), context false, ty 2))

  (* a pattern binding: a pattern that is no function's left-hand side *)
  and patBinding d =
    oneOf [(3, fn () => P (A.PVar (var ()))),
           (1, fn () => P (A.PTuple (several (2, 3, fn () => pat (d, true))))),
           (1, fn () => P (A.PCon (plainName (pick conNames), several (1, 2, fn () => apat d)))),
           (1, fn () => P (A.PLazy (apat d)))]

  and decl d =
    oneOf [(4, fn () => D (A.DFun (funlhs d, rhs (d, false)))),
           (2, fn () => D (A.DPat (patBinding d, rhs (d, false)))),
           (1, sigDecl),
           (1, fixityDecl)]

  and decls d = several (0, 3, fn () => decl d)

  fun constr d =
    let
      fun strict () = if chance (1, 4) then (true, atype 1) else (false, atype 1)
    in
      A.C (noAnn,
        oneOf [(3, fn () => A.CPlain (if chance (1, 6) then plainName (pick conSyms) else plainName (pick conNames),
                                      several (0, 3, strict))),
               (1, fn () => A.CInfix ((if chance (1, 4) then (true, atype 1) else (false, btype 1)),
                                      plainName (pick (conSyms @ ["K"])),
                                      (if chance (1, 4) then (true, atype 1) else (false, btype 1)))),
               (1, fn () => A.CRec (plainName (pick conNames),
                                    several (0, 2, fn () =>
                                      let val s = chance (1, 3)
                                      in A.Field (noAnn, several (1, 2, var), s, if s then atype 1 else ty 2) end)))])
    end

  fun deriving () =
    if chance (2, 3) then NONE
    else if chance (1, 3) then SOME (A.Deriv (noAnn, false, [plainName (pick classes)]))
    else SOME (A.Deriv (noAnn, true, several (0, 3, fn () => plainName (pick classes))))

  fun tyvars () = several (0, 2, tyvar)

  (* an instance head: a type constructor applied to distinct variables *)
  fun inst () =
    oneOf [(2, fn () => T (A.TCon (plainName (pick (tyCons @ ["()", "[]", "(->)", "(,)"]))))),
           (2, fn () => T (A.TParen (T (A.TApp (T (A.TCon (plainName "Maybe")), T (A.TVar (plainName "a"))))))),
           (1, fn () => T (A.TParen (T (A.TApp (T (A.TApp (T (A.TCon (plainName "Either")), T (A.TVar (plainName "a")))),
                                              T (A.TVar (plainName "b"))))))),
           (1, fn () => T (A.TList (T (A.TVar (plainName "a"))))),
           (1, fn () => T (A.TParen (T (A.TFun (T (A.TVar (plainName "a")), T (A.TVar (plainName "b"))))))),
           (1, fn () => T (A.TTuple [T (A.TVar (plainName "a")), T (A.TVar (plainName "b"))]))]

  fun classDecl d =
    D (A.DClass (context true, plainName "C", tyvar (),
                 if chance (1, 3) then NONE
                 else SOME (several (0, 3, fn () =>
                   oneOf [(2, sigDecl), (1, fixityDecl),
                          (2, fn () => D (A.DFun (funlhs d, rhs (d, false)))),
                          (1, fn () => D (A.DPat (P (A.PVar (var ())), rhs (d, false))))]))))

  fun instanceDecl d =
    D (A.DInstance (context true, if chance (1, 5) then name ("M", "Eq") else plainName (pick classes), inst (),
                    if chance (1, 3) then NONE
                    else SOME (several (0, 3, fn () =>
                      oneOf [(2, fn () => D (A.DFun (funlhs d, rhs (d, false)))),
                             (1, fn () => D (A.DPat (P (A.PVar (var ())), rhs (d, false))))]))))

  fun topdecl d =
    oneOf [(6, fn () => decl d),
           (1, fn () => D (A.DType (plainName (pick tyCons), tyvars (), ty 3))),
           (2, fn () => D (A.DData (context false, plainName (pick tyCons), tyvars (), several (1, 3, fn () => constr d),
                                    deriving ()))),
           (1, fn () => D (A.DNewtype (context false, plainName "N", tyvars (),
                                       if chance (1, 2) then A.C (noAnn, A.CPlain (plainName "N", [(false, atype 1)]))
                                       else A.C (noAnn, A.CRec (plainName "N", [A.Field (noAnn, [var ()], false, ty 2)])),
                                       deriving ()))),
           (1, fn () => classDecl d),
           (1, fn () => instanceDecl d),
           (1, fn () => D (A.DDefault (several (0, 2, fn () => ty 1))))]

  (* ---- modules ---- *)

  fun ent (inExport : bool) =
    A.Ent (noAnn,
      oneOf ([(3, fn () => A.EntVar (if inExport then qvar () else var ())),
              (1, fn () => A.EntVar (plainName (pick (List.filter (fn s => s <> "-") varSyms)))),
              (2, fn () => A.EntType (plainName (pick tyCons),
                                      oneOf [(1, fn () => NONE), (1, fn () => SOME A.SubAll),
                                             (1, fn () => SOME (A.SubList (several (0, 3, fn () =>
                                                if chance (1, 2) then plainName (pick conNames) else var ()))))]))]
             @ (if inExport then [(1, fn () => A.EntModule (plainName (pick ["M", "List"])))] else [])))

  fun import () =
    let
      val hiding = chance (1, 4)
    in
      A.Import (noAnn, {qualified = chance (1, 3), module = plainName (pick ["List", "Char", "M"]),
                        as_ = if chance (1, 3) then SOME (plainName "L") else NONE, hiding = hiding,
                        spec = if hiding orelse chance (1, 2) then SOME (several (0, 3, fn () => ent false)) else NONE})
    end

  fun module (n : int, d : int) : A.module =
    (seed n;
     let
       val header = chance (2, 3)
     in
       A.Module (noAnn,
         {name = if header then SOME (plainName "Main") else NONE,
          exports = if header andalso chance (1, 2) then SOME (several (0, 3, fn () => ent true)) else NONE,
          imports = several (0, 2, import),
          decls = several (1, 4, fn () => topdecl d)})
     end)
end
