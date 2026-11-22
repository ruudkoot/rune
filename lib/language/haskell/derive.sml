(* Implements: HS_DERIVE *)
structure HsDerive :> HS_DERIVE =
struct
  structure A = HsAst

  type constr = {name : A.name, arity : int, fields : A.name list, isInfix : bool, fixity : A.fixity * int}

  exception Missing of string

  fun methods {cls, constrs : constr list, entity, file} =
    let
      val counter = ref 0
      fun ann () = (counter := !counter + 1; {span = {file = file, start = !counter, stop = !counter + 1}, toks = []} : A.ann)
      (* an entity by its key *)
      fun named (space, n) =
        case entity (space, n) of
          SOME key =>
            (case String.fields (fn c => c = #"\t") key of
               [h, name] => A.Name (ann (), {qual = String.extract (h, 1, NONE), name = name})
             | _ => raise Missing n)
        | NONE => raise Missing n
      fun gname n = named ("v", n)
      fun clsName n = case entity ("t", n) of SOME k => k | NONE => ""
      fun lname n = A.Name (ann (), {qual = "", name = n ^ "#0"})
      fun e x = A.E (ann (), x)
      fun p x = A.P (ann (), x)
      fun var n = e (A.EVar (gname n))
      fun lvar n = e (A.EVar (lname n))
      fun conOf (c : constr) = A.Name (ann (), case #name c of A.Name (_, q) => q)
      fun econ (c : constr) = e (A.ECon (conOf c))
      fun gcon n = e (A.ECon (gname n))
      (* parentheses where the tree's printing needs them, as a user writes
         them, so that the methods read as source *)
      fun paren (x as A.E (_, y)) =
        case y of
          A.EApp _ => e (A.EParen x) | A.ESeq _ => e (A.EParen x) | A.ELam _ => e (A.EParen x)
        | A.ECase _ => e (A.EParen x) | A.EIf _ => e (A.EParen x) | A.ESig _ => e (A.EParen x)
        | _ => x
      fun app (f, args) = List.foldl (fn (a, f) => e (A.EApp (f, paren a))) f args
      fun binop (l, n, r) = e (A.ESeq [A.EA (paren l), A.EO (A.VarOp (gname n)), A.EA (paren r)])
      (* a name's code points, as the lexer read them from its UTF-8, and
         the string literal of them as Haskell writes it *)
      fun codes s = Utf8.explode s
      fun quoted s =
        let
          fun one (c, (prevNumeric, acc)) =
            if c >= 32 andalso c < 127 andalso c <> 34 andalso c <> 92 then
              (false, (if prevNumeric andalso c >= 48 andalso c <= 57 then "\\&" else "") ^ str (Char.chr c) :: acc)
            else (true, "\\" ^ Int.toString c :: acc)
        in
          "\"" ^ String.concat (List.rev (#2 (List.foldl one (false, []) (codes s)))) ^ "\""
        end
      fun lit l = A.Lit (ann (), l)
      fun str s = e (A.ELit (lit (A.LString (codes s, quoted s))))
      fun chr c = e (A.ELit (lit (A.LChar (Char.ord c, "'" ^ Char.toString c ^ "'"))))
      fun int n = e (A.ELit (lit (A.LInt (IntInf.fromInt n, Int.toString n))))
      fun pvar n = p (A.PVar (lname n))
      fun pcon (c : constr, ps) =
        let val q = p (A.PCon (conOf c, ps))
        in if null ps then q else p (A.PParen q) end
      fun pany (c : constr) = p (A.PRec (conOf c, []))
      fun pstr s = p (A.PLit (lit (A.LString (codes s, quoted s))))
      fun pint n = p (A.PLit (lit (A.LInt (IntInf.fromInt n, Int.toString n))))
      val pwild = fn () => p A.PWild
      fun ptuple ps = p (A.PTuple ps)
      fun rhs b = A.Rhs (ann (), A.Plain (b, NONE))
      fun clause (m, ps, b) = A.D (ann (), A.DFun (A.F (ann (), A.FPrefix (gname m, ps)), rhs b))
      fun alt (q, b) = A.Alt (ann (), q, rhs b)
      fun ecase (x, alts) = e (A.ECase (x, alts))
      fun gen (q, x) = A.S (ann (), A.SBind (q, x))
      fun guard x = A.S (ann (), A.SExp x)
      fun names (prefix, n) = List.tabulate (n, fn i => prefix ^ Int.toString (i + 1))
      fun conj [] = gcon "True"
        | conj [x] = x
        | conj (x :: rest) = binop (x, "&&", conj rest)
      fun compose [] = var "id"
        | compose [x] = x
        | compose (x :: rest) = binop (x, ".", compose rest)
      fun appendAll [] = e (A.EList [])
        | appendAll [x] = x
        | appendAll (x :: rest) = binop (x, "++", appendAll rest)
      fun isSymbolic (c : constr) = case #name c of A.Name (_, q) => A.isSymbolic q
      fun cname (c : constr) = case #name c of A.Name (_, {name, ...}) => name
      fun fname (f : A.name) = case f of A.Name (_, {name, ...}) => name
      (* a constructor's position, an Int by its signature, by a case: a
         literal alone would take its type from the module's `default` *)
      fun intType () = A.T (ann (), A.TCon (named ("t", "Int")))
      fun tag x =
        e (A.ESig (e (A.EParen (ecase (x, ListPair.map (fn (c, i) => alt (pany c, int i))
                                             (constrs, List.tabulate (length constrs, fn i => i))))),
                   NONE, intType ()))
      val enumeration = List.all (fn (c : constr) => #arity c = 0) constrs
      val first = hd constrs
      val last = List.last constrs
      fun bothArgs (c : constr) = (names ("a", #arity c), names ("b", #arity c))
      fun is n = cls = clsName n
    in
      SOME
        (if is "Eq" then
           List.map (fn c =>
                       let val (xs, ys) = bothArgs c
                       in
                         clause ("==", [pcon (c, List.map pvar xs), pcon (c, List.map pvar ys)],
                                 conj (ListPair.map (fn (x, y) => binop (lvar x, "==", lvar y)) (xs, ys)))
                       end) constrs
           @ (if length constrs > 1 then [clause ("==", [pwild (), pwild ()], gcon "False")] else [])
         else if is "Ord" then
           List.map (fn c =>
                       let
                         val (xs, ys) = bothArgs c
                         fun chain [] = gcon "EQ"
                           | chain [(x, y)] = app (var "compare", [lvar x, lvar y])
                           | chain ((x, y) :: rest) =
                               ecase (app (var "compare", [lvar x, lvar y]),
                                      [alt (p (A.PCon (gname "EQ", [])), chain rest), alt (pvar "o", lvar "o")])
                       in
                         clause ("compare", [pcon (c, List.map pvar xs), pcon (c, List.map pvar ys)], chain (ListPair.zip (xs, ys)))
                       end) constrs
           @ (if length constrs > 1 then [clause ("compare", [pvar "x", pvar "y"], app (var "compare", [tag (lvar "x"), tag (lvar "y")]))]
              else [])
         else if is "Enum" then
           ListPair.map (fn (c, i) => clause ("fromEnum", [pcon (c, [])], int i)) (constrs, List.tabulate (length constrs, fn i => i))
           @ [clause ("toEnum", [pvar "n"],
                      ecase (lvar "n", ListPair.map (fn (c, i) => alt (pint i, econ c)) (constrs, List.tabulate (length constrs, fn i => i))
                                       @ [alt (pwild (), app (var "error", [str "toEnum: bad argument"]))])),
              clause ("enumFrom", [pvar "x"], app (var "enumFromTo", [lvar "x", econ last])),
              clause ("enumFromThen", [pvar "x", pvar "y"],
                      app (var "enumFromThenTo",
                           [lvar "x", lvar "y",
                            e (A.EIf (binop (app (var "fromEnum", [lvar "y"]), ">=", app (var "fromEnum", [lvar "x"])),
                                      econ last, econ first))]))]
         else if is "Bounded" then
           if enumeration then [clause ("minBound", [], econ first), clause ("maxBound", [], econ last)]
           else
             [clause ("minBound", [], app (econ first, List.tabulate (#arity first, fn _ => var "minBound"))),
              clause ("maxBound", [], app (econ first, List.tabulate (#arity first, fn _ => var "maxBound")))]
         else if is "Ix" then
           if enumeration then
             [clause ("range", [ptuple [pvar "a", pvar "b"]],
                      e (A.EComp (lvar "c", [gen (pvar "c", e (A.EList (List.map econ constrs))),
                                             guard (binop (tag (lvar "c"), ">=", tag (lvar "a"))),
                                             guard (binop (tag (lvar "c"), "<=", tag (lvar "b")))]))),
              clause ("index", [ptuple [pvar "a", pvar "b"], pvar "c"],
                      e (A.EIf (app (var "inRange", [e (A.ETuple [lvar "a", lvar "b"]), lvar "c"]),
                                binop (tag (lvar "c"), "-", tag (lvar "a")),
                                app (var "error", [str "Ix.index: index out of range"])))),
              clause ("inRange", [ptuple [pvar "a", pvar "b"], pvar "c"],
                      binop (binop (tag (lvar "c"), ">=", tag (lvar "a")), "&&", binop (tag (lvar "c"), "<=", tag (lvar "b"))))]
           else
             let
               val c = first
               val ls = names ("l", #arity c) and us = names ("u", #arity c) and is_ = names ("i", #arity c)
               val bounds = ptuple [pcon (c, List.map pvar ls), pcon (c, List.map pvar us)]
               fun pair (l, u) = e (A.ETuple [lvar l, lvar u])
               val triples = ListPair.zip (ListPair.zip (ls, us), is_)
               fun indexOf [] = int 0
                 | indexOf (((l, u), i) :: rest) =
                     List.foldl (fn (((l, u), i), acc) =>
                                   binop (binop (acc, "*", app (var "rangeSize", [pair (l, u)])), "+",
                                          app (var "index", [pair (l, u), lvar i])))
                       (app (var "index", [pair (l, u), lvar i])) rest
             in
               [clause ("range", [bounds],
                        e (A.EComp (app (econ c, List.map lvar is_),
                                    List.map (fn ((l, u), i) => gen (pvar i, app (var "range", [pair (l, u)]))) triples))),
                clause ("index", [bounds, pcon (c, List.map pvar is_)], indexOf triples),
                clause ("inRange", [bounds, pcon (c, List.map pvar is_)],
                        conj (List.map (fn ((l, u), i) => app (var "inRange", [pair (l, u), lvar i])) triples))]
             end
         else if is "Show" then
           List.map (fn (c : constr) =>
                       let
                         val xs = names ("a", #arity c)
                         val (fix, prec) = #fixity c
                       in
                         if #arity c = 0 then
                           clause ("showsPrec", [pwild (), pcon (c, [])],
                                   app (var "showString", [str (if isSymbolic c then "(" ^ cname c ^ ")" else cname c)]))
                         else if not (null (#fields c)) then
                           clause ("showsPrec", [pvar "d", pcon (c, List.map pvar xs)],
                                   app (var "showParen",
                                        [binop (lvar "d", ">=", int 11),
                                         compose ([app (var "showString", [str ((if isSymbolic c then "(" ^ cname c ^ ")" else cname c) ^ " {")])] @
                                                  List.concat (ListPair.map (fn ((f, x), k) =>
                                                                               let val fn_ = fname f
                                                                                   val shown = if A.isSymbolic {qual = "", name = fn_} then "(" ^ fn_ ^ ")" else fn_
                                                                               in
                                                                                 [app (var "showString", [str ((if k = 0 then "" else ", ") ^ shown ^ " = ")]),
                                                                                  app (var "showsPrec", [int 0, lvar x])]
                                                                               end)
                                                                 (ListPair.zip (#fields c, xs), List.tabulate (length xs, fn i => i))) @
                                                  [app (var "showChar", [chr #"}"])])]))
                         else if #isInfix c andalso #arity c = 2 then
                           clause ("showsPrec", [pvar "d", pcon (c, List.map pvar xs)],
                                   app (var "showParen",
                                        [binop (lvar "d", ">", int prec),
                                         compose [app (var "showsPrec", [int (prec + 1), lvar (hd xs)]),
                                                  app (var "showString", [str (" " ^ (if isSymbolic c then cname c else "`" ^ cname c ^ "`") ^ " ")]),
                                                  app (var "showsPrec", [int (prec + 1), lvar (List.nth (xs, 1))])]]))
                         else
                           clause ("showsPrec", [pvar "d", pcon (c, List.map pvar xs)],
                                   app (var "showParen",
                                        [binop (lvar "d", ">", int 10),
                                         compose (app (var "showString", [str ((if isSymbolic c then "(" ^ cname c ^ ")" else cname c) ^ " ")]) ::
                                                  List.concat (ListPair.map (fn (x, k) =>
                                                                               (if k = 0 then [] else [app (var "showChar", [chr #" "])]) @
                                                                               [app (var "showsPrec", [int 11, lvar x])])
                                                                 (xs, List.tabulate (length xs, fn i => i))))]))
                       end)
             constrs
         else if is "Read" then
           let
             (* the tokens of a name as `lex` gives them *)
             fun lexemes (c : constr) = if isSymbolic c then ["(", cname c, ")"] else [cname c]
             fun one (c : constr) =
               let
                 val xs = names ("a", #arity c)
                 val (fix, prec) = #fixity c
                 val k = ref 0
                 fun next () = (k := !k + 1; "s" ^ Int.toString (!k))
                 (* a qualifier reading the token `t` from the state `s`, giving a new state *)
                 fun token (t, s) = let val s' = next () in (gen (ptuple [pstr t, pvar s'], app (var "lex", [lvar s])), s') end
                 fun value (x, prec, s) = let val s' = next () in (gen (ptuple [pvar x, pvar s'], app (var "readsPrec", [int prec, lvar s])), s') end
                 fun seq (steps, s) =
                   List.foldl (fn (f, (qs, s)) => let val (q, s') = f s in (qs @ [q], s') end) ([], s) steps
                 val (quals, final, paren) =
                   if #arity c = 0 then
                     let val (qs, s) = seq (List.map (fn t => fn s => token (t, s)) (lexemes c), "s0") in (qs, s, NONE) end
                   else if not (null (#fields c)) then
                     let
                       val steps =
                         List.map (fn t => fn s => token (t, s)) (lexemes c @ ["{"]) @
                         List.concat (ListPair.map (fn ((f, x), i) =>
                                                      (if i = 0 then [] else [fn s => token (",", s)]) @
                                                      (let val fn_ = fname f
                                                       in
                                                         if A.isSymbolic {qual = "", name = fn_} then
                                                           [fn s => token ("(", s), fn s => token (fn_, s), fn s => token (")", s)]
                                                         else [fn s => token (fn_, s)]
                                                       end) @
                                                      [fn s => token ("=", s), fn s => value (x, 0, s)])
                                        (ListPair.zip (#fields c, xs), List.tabulate (length xs, fn i => i))) @
                         [fn s => token ("}", s)]
                       val (qs, s) = seq (steps, "s0")
                     in
                       (qs, s, SOME 11)
                     end
                   else if #isInfix c andalso #arity c = 2 then
                     let
                       val opTokens = if isSymbolic c then [cname c] else ["`", cname c, "`"]
                       val steps = [fn s => value (hd xs, prec + 1, s)] @ List.map (fn t => fn s => token (t, s)) opTokens @
                                   [fn s => value (List.nth (xs, 1), prec + 1, s)]
                       val (qs, s) = seq (steps, "s0")
                     in
                       (qs, s, SOME prec)
                     end
                   else
                     let
                       val steps = List.map (fn t => fn s => token (t, s)) (lexemes c) @
                                   List.map (fn x => fn s => value (x, 11, s)) xs
                       val (qs, s) = seq (steps, "s0")
                     in
                       (qs, s, SOME 10)
                     end
                 val result = e (A.ETuple [app (econ c, List.map lvar xs), lvar final])
                 val reader = e (A.ELam ([pvar "s0"], e (A.EComp (result, quals))))
                 val cond = case paren of NONE => gcon "False" | SOME q => binop (lvar "d", ">", int q)
               in
                 app (var "readParen", [cond, reader, lvar "r"])
               end
             (* the infix constructors' alternatives first, as 10.5's figure
                has `:^:` before `Leaf` (der.tree.read.alternatives) *)
             val (infixes, others) = List.partition (fn (c : constr) => #isInfix c andalso #arity c = 2) constrs
           in
             [clause ("readsPrec", [pvar "d", pvar "r"], appendAll (List.map one (infixes @ others)))]
           end
         else raise Missing cls)
    end
    handle Missing _ => NONE
end
