functor BenchInferParsingFn (D : BENCH_SUSPEND) =
struct
  structure L = BenchLazy
  val defer = L.delay
  val expose = L.force
  datatype 'a node = Nil | Cons of 'a D.t * 'a node L.delay
  type 'a seq = 'a node L.delay
  fun empty () = L.delay (fn () => Nil)
  fun single x = L.delay (fn () => Cons (x, empty ()))
  fun append xs ys = L.delay (fn () => case L.force xs of
      Nil => L.force (ys ())
    | Cons (x, rest) => Cons (x, append rest ys))
  fun map f xs = L.delay (fn () => case L.force xs of Nil => Nil
    | Cons (x, rest) => Cons (D.delay (fn () => f (D.force x)), map f rest))
  fun bind xs f = L.delay (fn () => case L.force xs of Nil => Nil
    | Cons (x, rest) => L.force (append (f (D.force x)) (fn () => bind rest f)))
  fun fromList [] = empty ()
    | fromList (x :: xs) = L.delay (fn () => Cons (D.delay (fn () => x), fromList xs))
  fun toList xs = case L.force xs of Nil => []
    | Cons (x, rest) => D.force x :: toList rest
  fun fold f initial xs = case L.force xs of Nil => initial
    | Cons (x, rest) => fold f (f (D.force x, initial)) rest
  fun foldCells f initial xs = case L.force xs of Nil => initial
    | Cons (x, rest) => foldCells f (f (x, initial)) rest
  fun exists predicate xs = case L.force xs of Nil => false
    | Cons (x, rest) => predicate (D.force x) orelse exists predicate rest
  fun length xs = fold (fn (_, n) => n + 1) 0 xs

  type 'a parser = char list D.t -> ('a D.t * char list D.t) seq
  fun returnP x input = single (D.delay (fn () => (x, input)))
  fun thenP parser next input = bind (parser input) (fn (value, rest) => next value rest)
  fun eachP parser f = thenP parser (fn value => returnP (D.delay (fn () => f (D.force value))))
  fun elseP first second input = append (first input) (fn () => second input)
  fun failP _ = empty ()
  fun guardP condition parser = if condition then parser else failP
  fun filterP predicate parser = thenP parser (fn value => fn input =>
    if predicate (D.force value) then returnP value input else failP input)
  fun consP first rest = thenP first (fn x => thenP rest (fn xs =>
    returnP (D.delay (fn () => Cons (x, L.delay (fn () => D.force xs))))))
  fun cutP parser input =
    let val first = L.delay (fn () => case L.force (parser input) of
              Nil => raise Fail "infer parser cut: empty result"
            | Cons (pair, _) => D.force pair)
    in single (D.delay (fn () =>
         (D.delay (fn () => let val (value, _) = L.force first in D.force value end),
          D.delay (fn () => let val (_, rest) = L.force first in D.force rest end))))
    end
  fun starP parser input = cutP (elseP (plusP parser) (returnP (D.delay (fn () => Nil)))) input
  and plusP parser input = consP parser (starP parser) input
  fun endP input = case D.force input of [] => returnP (D.delay (fn () => ())) input
    | _ => failP input
  fun itemP input = case D.force input of [] => failP input
    | x :: xs => returnP (D.delay (fn () => x)) (D.delay (fn () => xs))
  fun litP c = filterP (fn x => x = c) itemP
  fun litsP [] = returnP (D.delay (fn () => Nil))
    | litsP (c :: cs) = consP (litP c) (litsP cs)
  fun exactlyP parser = thenP parser (fn value => thenP endP (fn _ => returnP value))
  fun spaceP input = filterP Char.isSpace itemP input
  fun alphaP input = filterP Char.isAlpha itemP input
  fun lowerP input = filterP Char.isLower itemP input
  fun upperP input = filterP Char.isUpper itemP input
  fun spacesP input = starP spaceP input
  fun lexicalP parser = thenP parser (fn value => thenP spacesP (fn _ => returnP value))
  fun lexP text = lexicalP (litsP (String.explode text))
  fun lexactlyP parser = thenP spacesP (fn _ => exactlyP parser)
  fun surroundP left parser right = thenP (lexP left) (fn _ =>
    thenP parser (fn value => thenP (lexP right) (fn _ => returnP value)))
  fun parenP parser = surroundP "(" parser ")"
  fun plusSepP separator parser = consP parser (starP (thenP (lexP separator) (fn _ => parser)))
  fun listP parser = surroundP "[" (elseP (plusSepP "," parser) (returnP (D.delay (fn () => Nil)))) "]"
  fun word node = String.implode (toList (L.delay (fn () => node)))
  fun useP fallback parser text = case L.force (parser (D.delay (fn () => String.explode text))) of
      Nil => fallback
    | Cons (pair, _) => let val (value, _) = D.force pair in D.force value end
end
