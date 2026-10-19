(* nofib clausify: suspended formula fields and ordered clause/list pipelines. *)
functor BenchClausifyFn (D : BENCH_SUSPEND) =
struct
  structure Q = BenchCellSequenceFn(D)
  datatype formula = Sym of char | Not of formula D.t
    | Dis of formula D.t * formula D.t | Con of formula D.t * formula D.t
    | Imp of formula D.t * formula D.t | Eqv of formula D.t * formula D.t
  datatype frame = Ast of formula D.t | Lex of char
  fun value x = D.delay(fn () => x)
  fun symbol c = value(Sym c)
  fun negate p = value(Not p)
  fun disjoin p q = value(Dis(p,q))
  fun conjoin p q = value(Con(p,q))
  fun priority #"(" = 0 | priority #"=" = 1 | priority #">" = 2
    | priority #"|" = 3 | priority #"&" = 4 | priority #"~" = 5
    | priority _ = raise Fail "unknown clausify operator"
  fun stackPriority (Ast _ :: Lex c :: _) = priority c
    | stackPriority _ = 0
  fun reduce (Ast p :: Lex #"=" :: Ast q :: s) = Ast(value(Eqv(q,p))) :: s
    | reduce (Ast p :: Lex #">" :: Ast q :: s) = Ast(value(Imp(q,p))) :: s
    | reduce (Ast p :: Lex #"|" :: Ast q :: s) = Ast(disjoin q p) :: s
    | reduce (Ast p :: Lex #"&" :: Ast q :: s) = Ast(conjoin q p) :: s
    | reduce (Ast p :: Lex #"~" :: s) = Ast(negate p) :: s
    | reduce _ = raise Fail "invalid clausify parse stack"
  fun reduceAll s = if stackPriority s = 0 then s else reduceAll(reduce s)
  fun parse text =
    let
      fun scan [] s = reduceAll s
        | scan (#" " :: t) s = scan t s
        | scan (#"(" :: t) s = scan t (Lex #"(" :: s)
        | scan (#")" :: t) s = (case reduceAll s of
            x :: Lex #"(" :: rest => scan t (x :: rest)
          | _ => raise Fail "unbalanced clausify parentheses")
        | scan (input as c :: t) s =
            if #"a" <= c andalso c <= #"z" then scan t (Ast(symbol c) :: s)
            else if stackPriority s > priority c then scan input (reduce s)
            else scan t (Lex c :: s)
    in case scan text [] of [Ast f] => f
      | _ => raise Fail "invalid clausify formula" end
  fun elim p = D.delay(fn () => case D.force p of
      Sym c => Sym c | Not q => Not(elim q)
    | Dis(q,r) => Dis(elim q,elim r) | Con(q,r) => Con(elim q,elim r)
    | Imp(q,r) => Dis(negate(elim q),elim r)
    | Eqv(q,r) => Con(elim(value(Imp(q,r))),elim(value(Imp(r,q)))))
  fun negin p = D.delay(fn () => case D.force p of
      Not q => (case D.force q of
          Not r => D.force(negin r)
        | Con(r,s) => Dis(negin(negate r),negin(negate s))
        | Dis(r,s) => Con(negin(negate r),negin(negate s))
        | _ => D.force p)
    | Dis(q,r) => Dis(negin q,negin r)
    | Con(q,r) => Con(negin q,negin r)
    | _ => D.force p)
  fun conjunct p = case D.force p of Con _ => true | _ => false
  fun disin p = D.delay(fn () => case D.force p of
      Dis(q,r) => (case D.force r of
          Con(s,t) => Con(disin(disjoin q s),disin(disjoin q t))
        | _ => (case D.force q of
            Con(s,t) => Con(disin(disjoin s r),disin(disjoin t r))
          | _ => let val dq = disin q val dr = disin r
              in if conjunct dq orelse conjunct dr
                 then D.force(disin(disjoin dq dr)) else Dis(dq,dr) end))
    | Con(q,r) => Con(disin q,disin r)
    | _ => D.force p)
  fun splitInto p rest = D.delay(fn () => case D.force p of
      Con(q,r) => D.force(splitInto q (splitInto r rest))
    | _ => Q.Cons(p,rest))
  fun split p = splitInto p (Q.empty())
  fun insert cmp x xs = D.delay(fn () => case D.force xs of
      Q.Nil => Q.Cons(x,Q.empty())
    | Q.Cons(y,ys) => (case cmp(D.force x,D.force y) of
        LESS => Q.Cons(x,xs) | EQUAL => D.force xs
      | GREATER => Q.Cons(y,insert cmp x ys)))
  fun clauseInto p acc = D.delay(fn () => case D.force p of
      Dis(q,r) => D.force(clauseInto q (clauseInto r acc))
    | Sym c => let val (positive,negative) = D.force acc
        in (insert Char.compare (value c) positive,negative) end
    | Not q => (case D.force q of Sym c =>
        let val (positive,negative) = D.force acc
        in (positive,insert Char.compare (value c) negative) end
      | _ => raise Fail "nonliteral clausify negation")
    | _ => raise Fail "nonclausal clausify formula")
  fun clause p = clauseInto p (value(Q.empty(),Q.empty()))
  fun member c xs = case D.force xs of Q.Nil => false
    | Q.Cons(x,rest) => c = D.force x orelse member c rest
  fun tautology cp =
    let val (positive,negative) = D.force cp
        fun loop xs = case D.force xs of Q.Nil => false
          | Q.Cons(x,rest) => member(D.force x)negative orelse loop rest
    in loop positive end
  fun compareChars (xs,ys) = case D.force xs of
      Q.Nil => (case D.force ys of Q.Nil => EQUAL | _ => LESS)
    | Q.Cons(x,xr) => (case D.force ys of Q.Nil => GREATER
      | Q.Cons(y,yr) => (case Char.compare(D.force x,D.force y) of
          EQUAL => compareChars(xr,yr) | result => result))
  fun compareClause ((c,a),(d,b)) = case compareChars(c,d) of
      EQUAL => compareChars(a,b) | result => result
  fun unique xs = D.delay(fn () => case D.force xs of Q.Nil => Q.Nil
    | Q.Cons(p,ps) => let val cp = clause p val rest = unique ps
        in if tautology cp then D.force rest
           else D.force(insert compareClause cp rest) end)
  fun leftDisplay xs = D.delay(fn () => case D.force xs of Q.Nil => Q.Nil
    | Q.Cons(x,rest) => Q.Cons(x,Q.cons(value #" ")(leftDisplay rest)))
  val arrow = Q.fromList(String.explode "<= ")
  val newline = Q.fromList[#"\n"]
  fun display cp = D.delay(fn () =>
    let val (positive,negative) = D.force cp
    in D.force(Q.append(leftDisplay positive)
      (Q.append arrow (Q.append(leftDisplay negative) newline))) end)
  fun concatMap f xs = D.delay(fn () => case D.force xs of Q.Nil => Q.Nil
    | Q.Cons(x,rest) => D.force(Q.append(f x)(concatMap f rest)))
  fun clauses text = concatMap display (unique(split(disin(negin(elim(parse text))))))
  val sample = String.explode "(a = a = a) = (a = a = a) = (a = a = a)"
  fun result n = concatMap (fn text => clauses(D.force text))
    (Q.replicate n (value sample))
  fun text xs = String.implode(Q.toList xs)
  fun validate expected xs =
    let val length = String.size expected
        fun loop xs i = case D.force xs of
            Q.Nil => if i=length then i else raise Fail "short clausify result"
          | Q.Cons(c,rest) => if i<length andalso D.force c=String.sub(expected,i)
              then loop rest(i+1) else raise Fail "clausify result differs"
    in loop xs 0 end
  fun checked expected n = validate expected (result n)
end
