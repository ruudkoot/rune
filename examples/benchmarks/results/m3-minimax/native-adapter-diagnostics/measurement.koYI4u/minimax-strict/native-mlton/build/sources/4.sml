functor BenchMinimaxFn (D : BENCH_SUSPEND) =
struct
  datatype 'a node = Nil | Cons of 'a D.t * 'a node D.t
  type 'a seq = 'a node D.t
  fun empty () = D.delay (fn () => Nil)
  fun ofList xs = D.delay (fn () => case xs of [] => Nil
    | x::rest => Cons (D.delay (fn () => x), ofList rest))
  fun map f xs = D.delay (fn () => case D.force xs of Nil => Nil
    | Cons (x, rest) => Cons (D.delay (fn () => f (D.force x)), map f rest))
  fun append xs ys = D.delay (fn () => case D.force xs of Nil => D.force ys
    | Cons (x, rest) => Cons (x, append rest ys))
  fun concat xs = D.delay (fn () => case D.force xs of Nil => Nil
    | Cons (x, rest) => D.force (append (D.force x) (concat rest)))
  fun map2 f xs ys = D.delay (fn () => case D.force xs of Nil => Nil
    | Cons (x, xr) => case D.force ys of Nil => Nil
      | Cons (y, yr) => Cons (D.delay (fn () => f (D.force x, D.force y)), map2 f xr yr))
  fun nth xs n = case D.force xs of Nil => raise Subscript
    | Cons (x, rest) => if n=0 then D.force x else nth rest (n-1)
  fun foldl f total xs = case D.force xs of Nil => total
    | Cons (x, rest) => foldl f (f (D.force x, total)) rest
  fun foldr f base xs = D.delay (fn () => case D.force xs of Nil => D.force base
    | Cons (x, rest) => f (D.force x, foldr f base rest))
  fun all f xs = case D.force xs of Nil => true
    | Cons (x, rest) => f (D.force x) andalso all f rest
  datatype piece = X | O | Empty
  datatype evaluation = XWin | OWin | Score of int
  type row = piece seq
  type board = row seq
  datatype 'a tree = Branch of 'a D.t * 'a tree D.t seq
  fun opposite X = O | opposite O = X | opposite Empty = raise Match
  fun range3 () = ofList [1,2,3]
  fun positions () = concat (map (fn x =>
    map (fn y => (x,y)) (range3 ())) (range3 ()))
  val wins = ofList (List.map (fn rows => ofList (List.map ofList rows))
    [[[1,1,1],[0,0,0],[0,0,0]], [[0,0,0],[1,1,1],[0,0,0]],
     [[0,0,0],[0,0,0],[1,1,1]], [[1,0,0],[1,0,0],[1,0,0]],
     [[0,1,0],[0,1,0],[0,1,0]], [[0,0,1],[0,0,1],[0,0,1]],
     [[1,0,0],[0,1,0],[0,0,1]], [[0,0,1],[0,1,0],[1,0,0]]])
  fun board rows = ofList (List.map ofList rows)
  fun initial () = board [[Empty,Empty,Empty],[Empty,Empty,Empty],[Empty,Empty,Empty]]
  fun testBoard () = board [[Empty,O,Empty],[Empty,X,Empty],[Empty,Empty,Empty]]
  fun conjunction values = case D.force values of Nil => true
    | Cons (x,rest) => D.force x andalso conjunction rest
  fun full b = conjunction (map (fn p => p<>Empty) (concat b))
  fun three xs = case D.force xs of Cons (a,ar) => (case D.force ar of
      Cons (b,br) => (case D.force br of Cons (c,cr) =>
        (case D.force cr of Nil => (a,b,c) | _ => raise Match) | _ => raise Match)
      | _ => raise Match) | _ => raise Match
  fun refs (a,b,c) = D.delay (fn () => Cons (a,D.delay (fn () =>
    Cons (b,D.delay (fn () => Cons (c,empty ()))))))
  fun replace xs n value =
    let val (a,b,c)=three xs
    in case n of 1 => refs (value,b,c) | 2 => refs (a,value,c)
      | 3 => refs (a,b,value) | _ => raise Match end
  fun select3 (a,b,c) n = case n of 1 => D.force a | 2 => D.force b
    | 3 => D.force c | _ => raise Match
  fun cell b (i,j) = select3 (three (select3 (three b) i)) j
  fun place p b (i,j) = if cell b (i,j)<>Empty then empty ()
    else ofList [replace b i (D.delay (fn () => replace (nth b (i-1)) j (D.delay (fn () => p))))]
  fun newPositions p b = concat (map (place p b) (positions ()))
  fun eval 3 = XWin | eval (~3) = OWin | eval n = Score n
  fun scorePiece (X,n) = n | scorePiece (O,n) = ~n | scorePiece (Empty,_) = 0
  fun sum xs = foldl (op +) 0 xs
  fun score b win = eval (sum (map sum (map2 (fn (xs,ys) => map2 scorePiece xs ys) b win)))
  fun static b =
    let fun interpret total values = case D.force values of Nil => Score total
          | Cons (x, rest) => case D.force x of Score n => interpret (total+n) rest
            | XWin => XWin | OWin => OWin
    in interpret 0 (map (score b) wins) end
  fun maximum XWin _ = XWin
    | maximum x y = (case D.force y of XWin => XWin | OWin => x
        | other as Score b => case x of OWin => other
          | Score a => if a>b then x else other | XWin => XWin)
  fun minimum OWin _ = OWin
    | minimum x y = (case D.force y of OWin => OWin | XWin => x
        | other as Score b => case x of XWin => other
          | Score a => if a<b then x else other | OWin => OWin)
  fun repeatTree f g value = D.delay (fn () =>
    Branch (D.delay (fn () => value), D.delay (fn () =>
      D.force (map (repeatTree g f) (f value)))))
  fun repTree p b = repeatTree (newPositions p) (newPositions (opposite p)) b
  fun prune depth tree = D.delay (fn () => case D.force tree of Branch (a, children) =>
    if depth<0 then raise Fail "Tree.prune: < 0"
    else Branch (a, if depth=0 then empty () else map (prune (depth-1)) children))
  fun mapTree f tree = D.delay (fn () => case D.force tree of Branch (a, children) =>
    Branch (D.delay (fn () => f (D.force a)), map (mapTree f) children))
  fun cropTree tree = D.delay (fn () => case D.force tree of Branch (a, children) =>
    case D.force children of Nil => Branch (a,empty ())
    | Cons _ => case D.force a of Score _ => Branch (a,map cropTree children)
      | _ => Branch (a,empty ()))
  fun mise f g tree = case D.force tree of Branch (a,children) =>
    case D.force children of Nil => D.force a
    | Cons _ => D.force (foldr (fn (x,rest) => f x rest)
        (D.delay (fn () => g OWin (D.delay (fn () => XWin))))
        (map (mise g f) children))
  fun bestMove p f g b = mise f g (cropTree (mapTree static (prune 5 (repTree p b))))
  fun best f boards scores =
    let fun loop b s bs ss = case (D.force bs,D.force ss) of (Nil,Nil) => (b,s)
          | (Cons (b',br),Cons (s',sr)) =>
              if s=f s s' then loop b s br sr
              else loop (D.force b') (D.force s') br sr
          | _ => raise Match
    in case (D.force boards,D.force scores) of (Cons (b,bs),Cons (s,ss)) =>
         loop (D.force b) (D.force s) bs ss | _ => raise Match end
  fun alternate p f g b = D.delay (fn () =>
    if full b orelse static b=XWin orelse static b=OWin then Nil
    else let val possibilities=newPositions p b
             val opposition=opposite p
             val scores=map (bestMove opposition g f) possibilities
             val move=D.delay (fn () => best f possibilities scores)
             val next=D.delay (fn () => case D.force move of (b',_) =>
               D.force (alternate opposition g f b'))
         in Cons (move,next) end)
  fun showPiece X = "X" | showPiece O = "O" | showPiece Empty = " "
  fun showRow r = let val (a,b,c)=three r in showPiece (D.force a)^"|"^showPiece (D.force b)^"|"^showPiece (D.force c) end
  fun showBoard b = let val (a,b,c)=three b in showRow (D.force a)^"\n------\n"^showRow (D.force b)^"\n------\n"^showRow (D.force c)^"\n\n" end
  fun showEvaluation XWin = "XWin" | showEvaluation OWin = "OWin"
    | showEvaluation (Score n) = if n<0 then "Score (-"^Int.toString (~n)^")" else "Score "^Int.toString n
  fun showMove (b,e) = showEvaluation e^"\n"^showBoard b
  fun prog input =
    let val b=testBoard ()
        val selected=if input="doesn't happen" then append b b else b
    in "OXO\n"^foldl (fn (move,text) => text^showMove move) "" (alternate X maximum minimum selected) end
end
