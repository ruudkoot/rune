functor BenchBoyerTwoFn (D : BENCH_SUSPEND) =
struct
  datatype node = Nil | Atom of string | Cons of node D.t * node D.t
  type term = node D.t
  datatype rulesNode = RNil | RCons of term * rulesNode D.t
  type rules = rulesNode D.t
  datatype lutNode = Empty | Node of lutNode D.t * string * rules * lutNode D.t
  type lut = lutNode D.t
  val nilTerm : term = D.delay (fn () => Nil)
  val noRules : rules = D.delay (fn () => RNil)
  fun emptyTerm () = nilTerm
  fun ruleCons term rest = D.delay (fn () => RCons (term, rest))
  fun atom s = D.delay (fn () => Atom s)
  fun cons a b = D.delay (fn () => Cons (a, b))
  fun tokens text =
    let val size = String.size text
        fun rest i = if i = size then i else
          let val c = String.sub (text, i)
          in if c = #"(" orelse c = #")" orelse c = #" " then i else rest (i + 1) end
        fun token i = if i = size then ("", i) else
          let val c = String.sub (text, i)
          in if c = #" " then token (i + 1)
             else if c = #"(" orelse c = #")" then (String.str c, i + 1)
             else let val j = rest i in (String.substring (text, i, j - i), j) end end
        fun loop i = if i = size then [] else
          let val (word, next) = token i in word :: loop next end
    in loop 0 end
  fun sublist [] = ([], emptyTerm ())
    | sublist ("(" :: rest) =
        let val (tail, left) = sublist rest val (last, right) = sublist tail
        in (last, cons left right) end
    | sublist (")" :: rest) = (rest, emptyTerm ())
    | sublist (word :: rest) =
        let val (last, tail) = sublist rest in (last, cons (atom word) tail) end
  fun parse text = case tokens text of
      "(" :: rest => let val (tail, term) = sublist rest
                      in if List.null tail then term else emptyTerm () end
    | _ => emptyTerm ()
  fun tv term = case D.force term of Atom s => s | _ => raise Fail "Not an atom"
  fun isAtom term = case D.force term of Atom _ => true | _ => false
  fun car term = case D.force term of Cons (a, _) => a | _ => emptyTerm ()
  fun cdr term = case D.force term of Cons (_, b) => b | _ => emptyTerm ()
  fun cadr term = car (cdr term)
  fun caddr term = car (cdr (cdr term))
  fun cadddr term = car (cdr (cdr (cdr term)))
  fun equal a b = case (D.force a, D.force b) of
      (Nil, Nil) => true
    | (Atom x, Atom y) => x = y
    | (Cons (x, xs), Cons (y, ys)) => equal x y andalso equal xs ys
    | _ => false
  fun assoc term bindings = case D.force bindings of
      Cons (entry, rest) => (case D.force entry of
          Cons (key, _) => (case D.force key of Atom _ => if equal term key then entry else assoc term rest | _ => emptyTerm ())
        | _ => emptyTerm ())
    | _ => emptyTerm ()
  fun add (key, rule, tree) = D.delay (fn () => case D.force tree of
      Empty => Node (D.delay (fn () => Empty), key, ruleCons rule noRules, D.delay (fn () => Empty))
    | Node (left, old, rules, right) =>
        if key = old then Node (left, old, ruleCons rule rules, right)
        else if String.compare (key, old) = LESS then Node (add (key, rule, left), old, rules, right)
        else Node (left, old, rules, add (key, rule, right)))
  fun lookup key tree = case D.force tree of Empty => noRules
    | Node (left, old, rules, right) => if key = old then rules
      else if String.compare (key, old) = LESS then lookup key left else lookup key right
  fun addLemma rule tree = case D.force rule of
      Nil => tree
    | Atom _ => raise Fail "Atoms can't be lemmas"
    | Cons (head, tail) =>
        let val lhs = car tail
        in if tv head = "equal" andalso not (isAtom lhs) then add (tv (car lhs), rule, tree)
           else raise Fail "Malformed lemma" end
  val lemmaCache = BenchLazy.delay (fn () =>
    List.foldl (fn (text, tree) => addLemma (parse text) tree) (D.delay (fn () => Empty)) BenchBoyerTwoRules.texts)
  fun applySubst bindings term = D.delay (fn () => case D.force term of
      Nil => Nil
    | Atom _ => (case D.force (assoc term bindings) of Cons (_, value) => D.force value | _ => D.force term)
    | Cons (head, tail) => Cons (head, applyList bindings tail))
  and applyList bindings terms = D.delay (fn () => case D.force terms of
      Nil => Nil | Atom _ => raise Fail "Malformed list"
    | Cons (head, tail) => Cons (applySubst bindings head, applyList bindings tail))
  fun unify first second bindings =
    if isAtom second then (case D.force (assoc second bindings) of
        Cons (_, value) => (equal first value, bindings)
      | _ => (true, cons (cons second first) bindings))
    else if isAtom first then (false, bindings)
    else if equal (car first) (car second) then unifyList (cdr first) (cdr second) bindings
    else (false, bindings)
  and unifyList first second bindings = case D.force first of Nil => (true, bindings)
    | _ => let val (matched, next) = unify (car first) (car second) bindings
           in if matched then unifyList (cdr first) (cdr second) next else (false, next) end
  fun rewrite tree term = D.delay (fn () => case D.force term of
      Nil => Nil | Atom _ => D.force term
    | Cons (head, tail) => D.force (rewriteRules tree (cons head (rewriteArgs tree tail)) (lookup (tv head) tree)))
  and rewriteArgs tree terms = D.delay (fn () => case D.force terms of
      Nil => Nil | Atom _ => raise Fail "Malformed list"
    | Cons (head, tail) => Cons (rewrite tree head, rewriteArgs tree tail))
  and rewriteRules tree term rules = case D.force rules of RNil => term
    | RCons (rule, rest) =>
        let val (matched, bindings) = unify term (cadr rule) (emptyTerm ())
        in if matched then rewrite tree (applySubst bindings (caddr rule)) else rewriteRules tree term rest end
  fun member term terms = case D.force terms of
      Cons (head, tail) => equal term head orelse member term tail
    | _ => false
  fun constant name term = case D.force term of
      Cons (head, tail) => (case (D.force head, D.force tail) of (Atom s, Nil) => s = name | _ => false)
    | _ => false
  fun truep term terms = case D.force term of Nil => false | _ => constant "t" term orelse member term terms
  fun falsep term terms = case D.force term of Nil => false | _ => constant "f" term orelse member term terms
  fun tautologyp term truths falsities = case D.force term of
      Nil => false
    | Atom _ => truep term truths
    | Cons (head, tail) =>
        if truep term truths then true else if falsep term falsities then false else
        (case D.force head of Atom "if" =>
            let val condition = car tail
            in if truep condition truths then tautologyp (cadr tail) truths falsities
               else if falsep condition falsities then tautologyp (caddr tail) truths falsities
               else tautologyp (cadr tail) (cons condition truths) falsities
                    andalso tautologyp (caddr tail) truths (cons condition falsities) end
          | _ => false)
  val statement = BenchLazy.delay (fn () => parse
    "( implies ( and ( implies x y ) ( and ( implies y z ) ( and ( implies z u ) ( implies u w ) ) ) ) ( implies x w ) )")
  fun subterm i =
    let val c = "c" ^ Int.toString i
    in parse (String.concat ["( ( x f ( plus ( plus a b ) ( plus ", c,
       " ( zero ) ) ) ) ( y f ( times ( times a b ) ( plus ", c,
       " d ) ) ) ( z f ( reverse ( append ( append a b ) ( [] ) ) ) ) (u equal ( plus a b ) ( difference x y ) ) (w lessp ( remainder a b ) ( member a ( length b ) ) ) )"]) end
  fun teststatement i = applySubst (subterm i) (BenchLazy.force statement)
  fun normal i = rewrite (BenchLazy.force lemmaCache) (teststatement i)
  fun test i = tautologyp (normal i) (emptyTerm ()) (emptyTerm ())
  fun write term emit = case D.force term of Nil => emit "()"
    | Atom s => emit s
    | Cons (head, tail) => (emit "("; write head emit; emit " . "; write tail emit; emit ")")
  fun ruleCount rules = case D.force rules of RNil => 0 | RCons (_, rest) => 1 + ruleCount rest
  fun entries tree = case D.force tree of Empty => []
    | Node (left, key, rules, right) => entries left @ ((key, ruleCount rules) :: entries right)

end
