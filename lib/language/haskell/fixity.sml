(* Implements: HS_FIXITY *)
structure HsFixity :> HS_FIXITY =
struct
  structure A = HsAst
  structure S = HsSource

  type fixity = A.fixity * int

  val default : fixity = (A.Infixl, 9)

  fun show (f, p) =
    (case f of A.Infix => "infix " | A.Infixl => "infixl " | A.Infixr => "infixr ") ^ Int.toString p

  val fixityOf : (A.qname -> fixity option) ref = ref (fn _ => NONE)
  val errors : (S.span * string) list ref = ref []

  exception Fail of S.span * string

  (* ---- names as the source wrote them ---- *)

  (* a local's unique name less the renamer's `#` and number *)
  fun stripLocal s =
    let
      fun go i =
        if i < 0 then s
        else if Char.isDigit (String.sub (s, i)) then go (i - 1)
        else if String.sub (s, i) = #"#" andalso i < size s - 1 andalso i > 0 then String.substring (s, 0, i)
        else s
    in
      go (size s - 1)
    end

  fun qopName (A.VarOp (A.Name (a, q))) = (a, q)
    | qopName (A.ConOp (A.Name (a, q))) = (a, q)

  fun opText q = let val (_, {qual, name}) = qopName q in if qual = "" then stripLocal name else name end
  fun opSpan q = #span (#1 (qopName q))
  fun fixOf q = getOpt (!fixityOf (#2 (qopName q)), default)

  fun joinSpans (a : S.span, b : S.span) =
    if #file a = "" then b else if #file b = "" then a else S.join (a, b)

  (* ---- the Report's algorithm of 10.6, over tokens ---- *)

  (* An operand (NONE for the hole a section leaves), an operator with a
     tag that tells it from the others of its sequence, or a negation. *)
  datatype 'a tok = X of 'a option | O of A.qop * int | N of S.span

  datatype 'a tree =
      Leaf of 'a option
    | Bin of 'a tree * (A.qop * int) * 'a tree
    | Negate of S.span * 'a tree

  type operator = {text : string, fix : fixity, negation : bool, span : S.span}

  fun describe (o1 : operator) =
    if #negation o1 then "negation (precedence 6, left-associative)"
    else "`" ^ #text o1 ^ "` (" ^ show (#fix o1) ^ ")"

  fun mixMessage (o1 : operator, o2 : operator) =
    let val ((f1, _), (f2, _)) = (#fix o1, #fix o2)
    in
      if f1 = A.Infix andalso f2 = A.Infix andalso not (#negation o1) then
        if #text o1 = #text o2 then
          "`" ^ #text o2 ^ "` is non-associative (" ^ show (#fix o2) ^ "), so " ^
          (if A.isSymbolic {qual = "", name = #text o2} then "`a " ^ #text o2 ^ " b " ^ #text o2 ^ " c`"
           else "a chain of it") ^ " needs parentheses"
        else
          "`" ^ #text o1 ^ "` and `" ^ #text o2 ^ "` are non-associative, of one precedence (" ^ show (#fix o2) ^
          "), so they cannot be mixed without parentheses"
      else
        describe o1 ^ " and " ^ describe o2 ^ " have one precedence and " ^
        (if f2 = A.Infix orelse (f1 = A.Infix andalso not (#negation o1)) then "one of them is non-associative"
         else "different associativity") ^ ", so they cannot be mixed without parentheses"
    end

  fun resolveToks (toks : 'a tok list) : 'a tree =
    let
      val bottom : operator = {text = "", fix = (A.Infix, ~1), negation = false, span = S.noSpan}
      fun parseNeg (o1 : operator, toks) =
        case toks of
          X e :: rest => parse1 (o1, Leaf e, rest)
        | N sp :: rest =>
            if #2 (#fix o1) >= 6 then
              raise Fail (sp, "a negation cannot be the right operand of " ^ describe o1 ^
                              ", which binds at least as tightly as negation (precedence 6): put the negation in parentheses")
            else
              let val (r, rest') = parseNeg ({text = "-", fix = (A.Infixl, 6), negation = true, span = sp}, rest)
              in parse1 (o1, Negate (sp, r), rest') end
        | _ => raise Fail (#span o1, "an operator with no operand after it")
      and parse1 (_, e, []) = (e, [])
        | parse1 (o1 : operator, e, toks as O (q, tag) :: rest) =
            let
              val (f1, p1) = #fix o1
              val fix2 as (f2, p2) = fixOf q
              val o2 = {text = opText q, fix = fix2, negation = false, span = opSpan q}
            in
              if p1 = p2 andalso (f1 <> f2 orelse f1 = A.Infix) then raise Fail (#span o2, mixMessage (o1, o2))
              else if p1 > p2 orelse (p1 = p2 andalso f1 = A.Infixl) then (e, toks)
              else
                let val (r, rest') = parseNeg (o2, rest)
                in parse1 (o1, Bin (e, (q, tag), r), rest') end
            end
        | parse1 (o1, _, _) = raise Fail (#span o1, "two operands with no operator between them")
    in
      case parseNeg (bottom, toks) of
        (t, []) => t
      | _ => raise Fail (S.noSpan, "an operator sequence that does not resolve")
    end

  (* the operator at the root of a tree, as a message names it *)
  fun rootText t =
    case t of
      Bin (_, (q, _), _) => "`" ^ opText q ^ "` (" ^ show (fixOf q) ^ ")"
    | Negate _ => "negation (precedence 6)"
    | Leaf _ => "an operand"

  (* ---- trees back to nodes ---- *)

  fun expTree t =
    case t of
      Leaf (SOME e) => e
    | Leaf NONE => raise Fail (S.noSpan, "a section's operand where it is not")
    | Bin (l, (q, _), r) =>
        let val (l', r') = (expTree l, expTree r)
        in A.E ({span = joinSpans (A.spanOfExp l', A.spanOfExp r'), toks = []}, A.ESeq [A.EA l', A.EO q, A.EA r']) end
    | Negate (sp, e) =>
        let val e' = expTree e
        in A.E ({span = joinSpans (sp, A.spanOfExp e'), toks = []}, A.ESeq [A.ENeg, A.EA e']) end

  fun patTree t =
    case t of
      Leaf (SOME p) => p
    | Leaf NONE => raise Fail (S.noSpan, "a hole in a pattern")
    | Bin (l, (q, _), r) =>
        let val (l', r') = (patTree l, patTree r)
        in A.P ({span = joinSpans (A.spanOfPat l', A.spanOfPat r'), toks = []}, A.PSeq [A.PA l', A.PO q, A.PA r']) end
    | Negate (_, Leaf (SOME p)) => p
    | Negate (sp, Bin (_, (q, _), _)) =>
        raise Fail (sp, "in a pattern, a negative literal cannot be the left operand of `" ^ opText q ^ "` (" ^
                        show (fixOf q) ^ "), which binds more tightly than negation (precedence 6): put it in parentheses")
    | Negate (sp, _) => raise Fail (sp, "a negation of other than a literal in a pattern")

  (* ---- the traversal ---- *)

  fun err (sp, msg) = errors := (sp, msg) :: !errors

  (* a sequence's tokens, with its operands resolved: each negation at its
     own `-` where the annotation has it *)
  fun expToks (ann : A.ann, items, first) =
    let
      val negs = List.length (List.filter (fn A.ENeg => true | _ => false) items)
      val file = #file (#span ann)
      val minus =
        if length (#toks ann) = negs then List.map (fn {start, stop, ...} => {file = file, start = start, stop = stop}) (#toks ann)
        else List.tabulate (negs, fn _ => #span ann)
      fun go ([], _, _, acc) = List.rev acc
        | go (A.EA e :: rest, ms, k, acc) = go (rest, ms, k, X (SOME (exp e)) :: acc)
        | go (A.EO q :: rest, ms, k, acc) = go (rest, ms, k + 1, O (q, k) :: acc)
        | go (A.ENeg :: rest, m :: ms, k, acc) = go (rest, ms, k, N m :: acc)
        | go (A.ENeg :: rest, [], k, acc) = go (rest, [], k, N (#span ann) :: acc)
    in
      go (items, minus, first, [])
    end

  and seqOf (A.E (a, x), e) =
    case x of
      A.ESeq items => expToks (a, items, 1)
    | _ => [X (SOME (exp e))]

  (* the operands back as a sequence, where resolution failed *)
  and unresolved (e as A.E (a, x), toks) =
    case (x, toks) of
      (A.ESeq _, _) =>
        A.E (a, A.ESeq (List.mapPartial (fn X (SOME e) => SOME (A.EA e) | X NONE => NONE | O (q, _) => SOME (A.EO q)
                                          | N _ => SOME A.ENeg) toks))
    | (_, [X (SOME e')]) => e'
    | _ => e

  and exp (e as A.E (a, x)) : A.exp =
    case x of
      A.ESeq items =>
        let val toks = expToks (a, items, 1)
        in expTree (resolveToks toks) handle Fail (sp, msg) => (err (sp, msg); unresolved (e, toks)) end
    | A.ELeftSec (operand, q) =>
        let
          val inner = seqOf (operand, operand)
          fun failed () = A.E (a, A.ELeftSec (unresolved (operand, inner), q))
        in
          (case resolveToks (inner @ [O (q, 0), X NONE]) of
             Bin (l, (_, 0), Leaf NONE) => A.E (a, A.ELeftSec (expTree l, q))
           | t =>
               (err (opSpan q,
                     "the operator `" ^ opText q ^ "` (" ^ show (fixOf q) ^ ") of a left section must bind more loosely " ^
                     "than its operand's, or as loosely with both left-associative, and " ^ rootText t ^
                     " in its operand does not: put the operand in parentheses");
                failed ()))
          handle Fail (sp, msg) => (err (sp, "in a section: " ^ msg); failed ())
        end
    | A.ERightSec (q, operand) =>
        let
          val inner = seqOf (operand, operand)
          fun failed () = A.E (a, A.ERightSec (q, unresolved (operand, inner)))
        in
          (case resolveToks ([X NONE, O (q, 0)] @ inner) of
             Bin (Leaf NONE, (_, 0), r) => A.E (a, A.ERightSec (q, expTree r))
           | t =>
               (err (opSpan q,
                     "the operator `" ^ opText q ^ "` (" ^ show (fixOf q) ^ ") of a right section must bind more loosely " ^
                     "than its operand's, or as loosely with both right-associative, and " ^ rootText t ^
                     " in its operand does not: put the operand in parentheses");
                failed ()))
          handle Fail (sp, msg) => (err (sp, "in a section: " ^ msg); failed ())
        end
    | _ => A.E (a, expForm x)

  and expForm x =
    case x of
      A.EApp (f, b) => A.EApp (exp f, exp b)
    | A.ELam (ps, b) => A.ELam (List.map pat ps, exp b)
    | A.ELet (ds, b) => A.ELet (decls ds, exp b)
    | A.EIf (c, t, e) => A.EIf (exp c, exp t, exp e)
    | A.ECase (e, alts) => A.ECase (exp e, List.map alt alts)
    | A.EDo ss => A.EDo (List.map stmt ss)
    | A.ETuple es => A.ETuple (List.map exp es)
    | A.EParen e => A.EParen (exp e)
    | A.EList es => A.EList (List.map exp es)
    | A.EEnum (f, t, u) => A.EEnum (exp f, Option.map exp t, Option.map exp u)
    | A.EComp (e, qs) => A.EComp (exp e, List.map stmt qs)
    | A.ERecCon (c, fs) => A.ERecCon (c, List.map (fn (f, e) => (f, exp e)) fs)
    | A.ERecUpd (e, fs) => A.ERecUpd (exp e, List.map (fn (f, e) => (f, exp e)) fs)
    | A.ESig (e, c, t) => A.ESig (exp e, c, t)
    | _ => x

  and stmt (A.S (a, s)) =
    A.S (a,
      case s of
        A.SBind (p, e) => A.SBind (pat p, exp e)
      | A.SLet ds => A.SLet (decls ds)
      | A.SExp e => A.SExp (exp e))

  and alt (A.Alt (a, p, r)) = A.Alt (a, pat p, rhs r)

  and rhs (A.Rhs (a, x)) =
    A.Rhs (a,
      case x of
        A.Plain (e, w) => A.Plain (exp e, Option.map decls w)
      | A.Guarded (gs, w) => A.Guarded (List.map (fn A.Guard (ga, g, e) => A.Guard (ga, exp g, exp e)) gs, Option.map decls w))

  (* a pattern's tokens: a negative literal is a negation and its literal *)
  and patToks (items, first) =
    let
      fun go ([], _, acc) = List.rev acc
        | go (A.PA (p as A.P (pa, A.PNegLit _)) :: rest, k, acc) = go (rest, k, X (SOME p) :: N (#span pa) :: acc)
        | go (A.PA p :: rest, k, acc) = go (rest, k, X (SOME (pat p)) :: acc)
        | go (A.PO q :: rest, k, acc) = go (rest, k + 1, O (q, k) :: acc)
    in
      go (items, first, [])
    end

  and patSeqOf (p as A.P (_, x)) =
    case x of
      A.PSeq items => patToks (items, 1)
    | A.PNegLit _ => patToks ([A.PA p], 1)
    | _ => [X (SOME (pat p))]

  (* the operands back as a sequence, where resolution failed *)
  and unresolvedPat (p as A.P (a, x), toks) =
    let
      fun items (N _ :: X (SOME q) :: rest) = A.PA q :: items rest
        | items (X (SOME q) :: rest) = A.PA q :: items rest
        | items (O (q, _) :: rest) = A.PO q :: items rest
        | items (_ :: rest) = items rest
        | items [] = []
    in
      case (x, items toks) of
        (A.PSeq _, is) => A.P (a, A.PSeq is)
      | (_, [A.PA q]) => q
      | _ => p
    end

  and pat (A.P (a, x)) : A.pat =
    case x of
      A.PSeq items =>
        let val toks = patToks (items, 1)
        in patTree (resolveToks toks) handle Fail (sp, msg) => (err (sp, msg); unresolvedPat (A.P (a, x), toks)) end
    | A.PCon (c, ps) => A.P (a, A.PCon (c, List.map pat ps))
    | A.PRec (c, fs) => A.P (a, A.PRec (c, List.map (fn (f, p) => (f, pat p)) fs))
    | A.PTuple ps => A.P (a, A.PTuple (List.map pat ps))
    | A.PList ps => A.P (a, A.PList (List.map pat ps))
    | A.PParen p => A.P (a, A.PParen (pat p))
    | A.PAs (v, p) => A.P (a, A.PAs (v, pat p))
    | A.PLazy p => A.P (a, A.PLazy (pat p))
    | A.PJux ps => A.P (a, A.PJux (List.map pat ps))
    | _ => A.P (a, x)

  (* `p1 op p2` on the left of an equation: op at the root, by precedence *)
  and funlhs (A.F (a, x)) =
    A.F (a,
      case x of
        A.FPrefix (f, ps) => A.FPrefix (f, List.map pat ps)
      | A.FInfix (p1, q, p2) =>
          let
            val (t1, t2) = (patSeqOf p1, patSeqOf p2)
            fun failed () = A.FInfix (unresolvedPat (p1, t1), q, unresolvedPat (p2, t2))
          in
            (case resolveToks (t1 @ [O (q, 0)] @ t2) of
               Bin (l, (_, 0), r) => A.FInfix (patTree l, q, patTree r)
             | t =>
                 (err (opSpan q,
                       "by precedence this left-hand side does not define `" ^ opText q ^ "` (" ^ show (fixOf q) ^
                       "): " ^ rootText t ^ " in an operand binds more loosely; put the operand in parentheses");
                  failed ()))
            handle Fail (sp, msg) => (err (sp, msg); failed ())
          end
      | A.FParen (l, ps) => A.FParen (funlhs l, List.map pat ps))

  and decl (A.D (a, x)) =
    A.D (a,
      case x of
        A.DFun (f, r) => A.DFun (funlhs f, rhs r)
      | A.DPat (p, r) => A.DPat (pat p, rhs r)
      | A.DClass (cx, c, v, body) => A.DClass (cx, c, v, Option.map decls body)
      | A.DInstance (cx, c, t, body) => A.DInstance (cx, c, t, Option.map decls body)
      | _ => x)

  and decls ds = List.map decl ds

  fun resolve {fixityOf = f} (A.Module (a, {name, exports, imports, decls = ds})) =
    let
      val () = (fixityOf := f; errors := [])
      val ds' = decls ds
      val errs = List.rev (!errors)
    in
      errors := [];
      fixityOf := (fn _ => NONE);
      (A.Module (a, {name = name, exports = exports, imports = imports, decls = ds'}), errs)
    end
end
