functor BenchInferFn (D : BENCH_SUSPEND) =
struct
  structure P = BenchInferParsingFn (D)
  datatype mono = TVar of string | TCon of string * mono P.seq
  datatype term = Var of string | Abs of string * term D.t
    | App of term D.t * term D.t | Let of string * term D.t * term D.t
  datatype poly = All of string P.seq * mono D.t
  type sub = (string * mono D.t) P.seq
  type env = (string * poly) P.seq
  type 'a infer = sub -> int -> (('a * sub) * int) option
  fun arrow first second = D.delay (fn () => TCon ("->",
    D.delay (fn () => P.Cons (first, D.delay (fn () => P.Cons (second, P.empty ()))))))
  fun lookup fallback entries name = case D.force entries of P.Nil => fallback ()
    | P.Cons (entry, rest) => let val (key, value) = D.force entry
        in if key = name then value else lookup fallback rest name end
  fun member name names = P.exists (fn other => name = other) names
  fun nub names =
    let fun loop seen xs = D.delay (fn () => case D.force xs of P.Nil => P.Nil
          | P.Cons (x, rest) => let val name = D.force x
            in if List.exists (fn old => old = name) seen then D.force (loop seen rest)
               else P.Cons (x, loop (name :: seen) rest) end)
    in loop [] names end
  fun remove name names = D.delay (fn () => case D.force names of P.Nil => P.Nil
    | P.Cons (x, rest) => if name = D.force x then D.force rest
                         else P.Cons (x, remove name rest))
  fun minus xs ys = P.fold (fn (name, names) => remove name names) xs ys
  fun freeNode (TVar name) = P.single (D.delay (fn () => name))
    | freeNode (TCon (_, args)) = P.bind args freeNode
  fun freeMono mono = D.delay (fn () => D.force (freeNode (D.force mono)))
  fun freePoly (All (names, mono)) = minus (nub (freeMono mono)) names
  fun freeEnv entries = P.bind entries (fn (_, value) => freePoly value)
  fun lookupSub substitution name = lookup (fn () => D.delay (fn () => TVar name)) substitution name
  fun applyNode substitution (TVar name) = D.force (lookupSub substitution name)
    | applyNode substitution (TCon (name, args)) = TCon (name, P.map (applyNode substitution) args)
  fun applySub substitution mono = D.delay (fn () => applyNode substitution (D.force mono))
  fun extendSub substitution name mono =
    let val value = applySub substitution mono
        val entry = D.delay (fn () => (name,value))
        val unit = P.single entry
    in D.delay (fn () => P.Cons (entry,
         P.map (fn (key, old) => (key, applySub unit old)) substitution))
    end
  fun equal first second = case D.force first of
      TVar name => (case D.force second of TVar other => name = other | _ => false)
    | TCon (name, args) => (case D.force second of TCon (other, values) =>
        name = other andalso equalArgs args values | _ => false)
  and equalArgs first second = case (D.force first, D.force second) of
      (P.Nil, P.Nil) => true
    | (P.Cons (x,xs), P.Cons (y,ys)) => equal x y andalso equalArgs xs ys
    | _ => false
  fun unify first second substitution = case D.force first of
      TVar name => unifyVar name second substitution
    | TCon (name, args) => (case D.force second of
        TVar other => unifyVar other first substitution
      | TCon (other, values) => if name = other then unifies args values substitution else NONE)
  and unifies first second substitution = case (D.force first, D.force second) of
      (P.Nil, P.Nil) => SOME substitution
    | (P.Cons (x,xs), P.Cons (y,ys)) =>
        (case unify x y substitution of NONE => NONE | SOME next => unifies xs ys next)
    | _ => raise Fail "infer unifies: unequal constructor arity"
  and unifyVar name mono substitution =
    if P.exists (fn (key,_) => key = name) substitution
    then unify (lookupSub substitution name) mono substitution
    else if equal (D.delay (fn () => TVar name)) mono then SOME substitution
    else if member name (freeMono mono) then NONE
    else SOME (extendSub substitution name mono)

  fun returnI value substitution counter = SOME ((value, substitution), counter)
  fun thenI computation next substitution counter = case computation substitution counter of
      NONE => NONE | SOME ((value, updated), count) => next value updated count
  fun getSubI substitution counter = returnI substitution substitution counter
  fun substituteI mono = thenI getSubI (fn substitution => returnI (applySub substitution mono))
  fun freshI substitution counter =
    returnI (D.delay (fn () => TVar ("a" ^ Int.toString counter))) substitution (counter + 1)
  fun freshesI 0 = returnI (P.empty ())
    | freshesI n = thenI freshI (fn x => thenI (freshesI (n-1)) (fn xs =>
        returnI (D.delay (fn () => P.Cons (x,xs)))))
  fun zip first second = D.delay (fn () => case (D.force first, D.force second) of
      (P.Cons (x,xs), P.Cons (y,ys)) => P.Cons
        (D.delay (fn () => (D.force x, y)), zip xs ys)
    | _ => P.Nil)
  fun specialiseI (All (names, mono)) = thenI (freshesI (P.length names)) (fn fresh =>
    returnI (applySub (zip names fresh) mono))
  fun generaliseI entries mono = thenI getSubI (fn substitution =>
    returnI (All (D.delay (fn () =>
      let val bound = nub (P.bind (freeEnv entries) (fn name => freeMono (lookupSub substitution name)))
      in D.force (minus (nub (freeMono mono)) bound) end), mono)))
  fun unifyI first second substitution counter = case unify first second substitution of
      NONE => NONE | SOME updated => returnI () updated counter
  fun extend entries name value = D.delay (fn () => P.Cons
    (D.delay (fn () => (name,value)), entries))
  fun inferTerm entries input substitution counter =
    (case D.force input of
      Var name => if P.exists (fn (key,_) => key = name) entries
        then thenI (specialiseI (lookup (fn () => raise Fail "lookup") entries name))
          (fn mono => substituteI mono)
        else (fn _ => fn _ => NONE)
    | Abs (name,body) => thenI freshI (fn fresh =>
        thenI (inferTerm (extend entries name (All (P.empty (),fresh))) body) (fn result =>
        thenI (substituteI fresh) (fn argument => returnI (arrow argument result))))
    | App (function,argument) => thenI (inferTerm entries function) (fn first =>
        thenI (inferTerm entries argument) (fn second => thenI freshI (fn result =>
        thenI (unifyI first (arrow second result)) (fn () => substituteI result))))
    | Let (name,value,body) => thenI (inferTerm entries value) (fn mono =>
        thenI (generaliseI entries mono) (fn polymorphic => inferTerm (extend entries name polymorphic) body)))
      substitution counter

  fun chars node = P.word node
  fun idParser input = P.lexicalP (P.filterP (fn word => word <> "let" andalso word <> "in")
    (P.eachP (P.plusP P.alphaP) chars)) input
  fun lowerId input = P.eachP (P.lexicalP (P.consP P.lowerP (P.starP P.alphaP))) chars input
  fun upperId input = P.eachP (P.lexicalP (P.consP P.upperP (P.starP P.alphaP))) chars input
  fun readsMono depth input = P.elseP (P.guardP (depth<=1) readsArrow)
    (P.elseP (P.guardP (depth<=9) readsCon)
      (P.elseP readsTypeVar (P.parenP (readsMono 0)))) input
  and readsArrow input = P.thenP (readsMono 2) (fn first =>
    P.thenP (P.lexP "->") (fn _ => P.thenP (readsMono 1) (fn second => P.returnP (arrow first second)))) input
  and readsCon input = P.thenP upperId (fn name => P.thenP (P.starP (readsMono 10))
    (fn args => P.returnP (D.delay (fn () => TCon (D.force name,args))))) input
  and readsTypeVar input = P.thenP lowerId (fn name => P.returnP (D.delay (fn () => TVar (D.force name)))) input
  fun readsPoly input = P.thenP (readsMono 0) (fn mono =>
    P.returnP (D.delay (fn () => All (nub (freeMono mono),mono)))) input
  fun readsPair input = P.thenP idParser (fn name => P.thenP (P.lexP ":") (fn _ =>
    P.thenP readsPoly (fn mono => P.returnP (D.delay (fn () => (D.force name,D.force mono)))))) input
  fun readsEnv input = P.listP readsPair input
  fun abstraction names body = D.delay (fn () => case D.force names of
      P.Nil => D.force body
    | P.Cons (name,rest) => Abs (D.force name, abstraction rest body))
  fun readsTerm input = P.elseP readsAbs (P.elseP readsLet readsAtomics) input
  and readsAtomic input = P.elseP readsVar (P.parenP readsTerm) input
  and readsVar input = P.thenP idParser (fn name => P.returnP (D.delay (fn () => Var (D.force name)))) input
  and readsAbs input = P.thenP (P.lexP "\\") (fn _ => P.thenP (P.plusP idParser) (fn names =>
    P.thenP (P.lexP ".") (fn _ => P.thenP readsTerm (fn body => P.returnP (abstraction names body))))) input
  and readsLet input = P.thenP (P.lexP "let") (fn _ => P.thenP idParser (fn name =>
    P.thenP (P.lexP "=") (fn _ => P.thenP readsTerm (fn value =>
    P.thenP (P.lexP "in") (fn _ => P.thenP readsTerm (fn body =>
      P.returnP (D.delay (fn () => Let (D.force name,value,body))))))))) input
  and readsAtomics input = P.thenP readsAtomic (fn first =>
    P.thenP (P.starP readsAtomic) (fn rest => P.returnP
      (P.foldCells (fn (argument,acc) => D.delay (fn () => App (acc,argument))) first rest))) input

  val environmentText = "[ unit   : x -> List x,  append : List x -> List x -> List x,  fix    : (x -> x) -> x ]"
  val testEnv = D.delay (fn () => P.useP P.Nil (P.lexactlyP readsEnv) environmentText)
  fun word text = P.fromList (String.explode text)
  fun cat parts = D.delay (fn () => case parts of [] => P.Nil
    | first :: rest => D.force (P.append (first ()) (fn () => cat rest)))
  fun parens condition body = if condition then cat [fn () => word "(", body, fn () => word ")"] else body ()
  fun separated separator render values = D.delay (fn () => case D.force values of
      P.Nil => P.Nil
    | P.Cons (x,rest) => D.force (P.append (render x) (fn () => prefixed separator render rest)))
  and prefixed separator render values = D.delay (fn () => case D.force values of
      P.Nil => P.Nil
    | P.Cons (x,rest) => D.force (cat [fn () => word separator, fn () => render x,
        fn () => prefixed separator render rest]))
  fun arrowArgs args = case D.force args of P.Cons (x,rest) =>
      (case D.force rest of P.Cons (y,last) => (case D.force last of P.Nil => SOME (x,y) | _ => NONE)
       | _ => NONE) | _ => NONE
  fun showMono depth input = D.delay (fn () => D.force (case D.force input of
      TVar name => word name
    | TCon (name,args) =>
      let fun ordinary () = parens (depth>9) (fn () => cat
            [fn () => word name, fn () => prefixed " " (showMono 10) args])
      in if name="->" then case arrowArgs args of
           NONE => ordinary ()
         | SOME (first,second) => parens (depth>1) (fn () => cat
             [fn () => showMono 2 first, fn () => word " -> ", fn () => showMono 1 second])
         else ordinary ()
      end))
  fun showPoly (All (names,mono)) = cat [fn () => word "All ",
    fn () => separated " " (fn x => word (D.force x)) names,
    fn () => word ". ", fn () => showMono 0 mono]
  fun showPair pair = let val (name,poly) = D.force pair
    in cat [fn () => word name, fn () => word " : ", fn () => showPoly poly] end
  fun showEnv values = cat [fn () => word "[", fn () => separated ",\n " showPair values, fn () => word "]"]
  fun showTerm depth input = D.delay (fn () => D.force (case D.force input of
      Var name => word name
    | Abs (name,body) => parens (depth>0) (fn () => cat
        [fn () => word "\\", fn () => word name, fn () => showAbs body])
    | App (function,argument) => parens (depth>1) (fn () => cat
        [fn () => showTerm 1 function, fn () => word " ", fn () => showTerm 2 argument])
    | Let (name,value,body) => parens (depth>0) (fn () => cat
        [fn () => word "let  ", fn () => word name, fn () => word " = ", fn () => showTerm 1 value,
         fn () => word "  in  ", fn () => showTerm 0 body])))
  and showAbs input = D.delay (fn () => D.force (case D.force input of
      Abs (name,body) => cat [fn () => word " ", fn () => word name, fn () => showAbs body]
    | _ => cat [fn () => word ". ", fn () => showTerm 0 input]))
  val prompt = word "\n? "
  val parseFailure = cat [fn () => word "Failed to parse", fn () => prompt]
  val typeFailure = cat [fn () => word "Failed to type", fn () => prompt]
  val header = cat [fn () => showEnv testEnv, fn () => prompt]
  fun readInferShow line = D.delay (fn () => D.force (
    case D.force (P.lexactlyP readsTerm (D.delay (fn () => String.explode line))) of
      P.Nil => parseFailure
    | P.Cons (pair,_) => let val (input,_) = D.force pair
      in case inferTerm testEnv input (P.empty ()) 0 of NONE => typeFailure
       | SOME ((mono,_),_) => cat [fn () => showTerm 0 input, fn () => word " : ",
           fn () => showMono 0 mono, fn () => prompt]
      end))
  fun lines text = if String.size text=0 then [] else
    let val values = String.fields (fn c => c = #"\n") text
    in if String.sub (text,String.size text-1) = #"\n" then List.rev (tl (List.rev values)) else values end
  fun outputs [] = P.empty ()
    | outputs (line::rest) = P.append (readInferShow line) (fn () => outputs rest)
  fun render text = P.append header (fn () => outputs (lines text))
  fun app emit text = case D.force text of P.Nil => ()
    | P.Cons (x,rest) => (emit (D.force x); app emit rest)
end
