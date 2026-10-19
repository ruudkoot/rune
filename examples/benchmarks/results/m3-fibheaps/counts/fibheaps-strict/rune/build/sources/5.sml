(* Okasaki's two degree-consolidation algorithms over the original bag forest. *)
functor BenchFibHeapsFn(D : BENCH_SUSPEND) =
struct
  structure Q = BenchCellSequenceFn(D)
  datatype tree = Node of int D.t * tree D.t Q.sequence
  type tagged = int D.t * tree D.t
  datatype bag = EmptyBag | ConsBag of tagged D.t * bag D.t | UnionBags of bag D.t * bag D.t
  datatype heap = EmptyFH | FH of int D.t * tagged D.t * bag D.t
  fun value x = Q.value x
  fun emptyBag () = value EmptyBag
  fun emptyHeap () = value EmptyFH
  fun root tree = let val Node(key,_) = D.force tree in D.force key end
  fun taggedRoot entry = let val (_,tree) = D.force entry in root tree end
  fun link left right = D.delay(fn () =>
    let val Node(x,xs) = D.force left
        val Node(y,ys) = D.force right
    in if D.force x <= D.force y then Node(x,Q.cons(value right)xs)
       else Node(y,Q.cons(value left)ys)end)
  fun children entry =
    let val (degree,tree) = D.force entry
        val Node(_,trees) = D.force tree
        fun loop offset trees = D.delay(fn () => case D.force trees of Q.Nil => Q.Nil
          | Q.Cons(tree,rest) => Q.Cons(D.delay(fn () =>
              (D.delay(fn () => D.force degree-1-offset),D.force tree)),loop(offset+1)rest))
    in loop 0 trees end
  fun flatten bag finish = D.delay(fn () => case D.force bag of
      EmptyBag => D.force finish
    | ConsBag(entry,rest) => D.force(flatten rest (Q.cons entry finish))
    | UnionBags(left,right) => D.force(flatten left (flatten right finish)))
  fun apply function bag = case D.force bag of EmptyBag => ()
    | ConsBag(entry,rest) => (function(D.force entry);apply function rest)
    | UnionBags(left,right) => (apply function left;apply function right)
  fun singleton key = D.delay(fn () => FH(value 1,
    D.delay(fn () => (value 0,D.delay(fn () => Node(key,Q.empty())))),emptyBag()))
  fun meld left right = D.delay(fn () => case D.force left of EmptyFH => D.force right
    | FH(n,a,as') => case D.force right of EmptyFH => D.force left
      | FH(m,b,bs) =>
          let val size = D.delay(fn () => D.force n+D.force m)
              val joined = D.delay(fn () => UnionBags(as',bs))
          in if taggedRoot a<=taggedRoot b then FH(size,a,D.delay(fn () => ConsBag(b,joined)))
             else FH(size,b,D.delay(fn () => ConsBag(a,joined)))end)
  fun make input = D.delay(fn () => case D.force input of Q.Nil => EmptyFH
    | Q.Cons(key,rest) => D.force(meld(singleton key)(make rest)))
  fun app function xs = case D.force xs of Q.Nil => ()
    | Q.Cons(x,rest) => (function(D.force x);app function rest)
  fun log2 1 = 0 | log2 n = 1+log2(n div 2)
  fun deleteMutable heap = D.delay(fn () => case D.force heap of EmptyFH => raise Empty
    | FH(size,minimum,forest) =>
        let val n = D.force size
        in if n=1 then EmptyFH else
          let val degree = log2(n-1)
              val slots = Array.array(degree+1,NONE : tree D.t option)
              fun insert (index,tree) = case Array.sub(slots,index)of
                  NONE => Array.update(slots,index,SOME tree)
                | SOME old => (Array.update(slots,index,NONE);insert(index+1,link tree old))
              val _ = apply(fn (index,tree) => insert(D.force index,tree))forest
              val _ = app(fn entry => let val (index,tree)=entry in insert(D.force index,tree)end)
                    (children minimum)
              val top = valOf(Array.sub(slots,degree))
              fun minimumAt i best bag = if i>=degree then (best,bag) else
                case Array.sub(slots,i)of NONE => minimumAt(i+1)best bag
                | SOME tree =>
                    if taggedRoot best<=root tree then
                      minimumAt(i+1)best(D.delay(fn () => ConsBag(value(value i,tree),bag)))
                    else minimumAt(i+1)(value(value i,tree))(D.delay(fn () => ConsBag(best,bag)))
              val (next,bag) = minimumAt 0 (value(value degree,top))(emptyBag())
          in FH(value(n-1),next,bag)end
        end)
  fun deleteFunctional heap = D.delay(fn () => case D.force heap of EmptyFH => raise Empty
    | FH(size,minimum,forest) =>
        let val n = D.force size
        in if n=1 then EmptyFH else
          let val consolidated = D.delay(fn () =>
                let val degree = log2(n-1)
              val slots = Array.array(degree+1,Q.empty() : tree D.t Q.sequence)
              fun accumulate entry =
                let val (index,tree) = entry
                    val i = D.force index
                in Array.update(slots,i,Q.cons(value tree)(Array.sub(slots,i)))end
              val entries = Q.append(children minimum)(flatten forest(Q.empty()))
              val _ = app accumulate entries
              fun buckets i = if i>degree then [] else Array.sub(slots,i)::buckets(i+1)
              fun startup index trees rest = D.delay(fn () => case D.force trees of
                  Q.Nil => (case rest of [] => Q.Nil | next::tail => D.force(startup(index+1)next tail))
                | _ => case rest of [] => D.force(combine index trees (Q.empty())[])
                    | next::tail => D.force(combine index trees next tail))
              and combine index trees next rest = D.delay(fn () => case D.force trees of
                  Q.Nil => D.force(startup(index+1)next rest)
                | Q.Cons(first,tail) => case D.force tail of
                    Q.Nil => Q.Cons(value(value index,D.force first),startup(index+1)next rest)
                  | Q.Cons(second,others) => D.force(combine index others
                      (Q.cons(value(link(D.force first)(D.force second)))next)rest))
              val lists = buckets 0
              val linked = startup 0 (hd lists)(tl lists)
              fun choose (entry,(best,bag)) = if taggedRoot best<=taggedRoot(value entry) then
                    (best,D.delay(fn () => ConsBag(value entry,bag)))
                  else (value entry,D.delay(fn () => ConsBag(best,bag)))
              val first = Q.head linked
              val (next,bag) = List.foldl choose (value first,emptyBag())(Q.toList(Q.tail linked))
                in (next,bag)end)
          in FH(value(n-1),D.delay(fn () => D.force(#1(D.force consolidated))),
                D.delay(fn () => D.force(#2(D.force consolidated))))end
        end)
  fun toList delete heap = D.delay(fn () => case D.force heap of EmptyFH => Q.Nil
    | FH(_,minimum,_) => Q.Cons(D.delay(fn () => taggedRoot minimum),toList delete(delete heap)))
  fun randoms count =
    let fun loop 0 _ = Q.empty()
          | loop n seed = D.delay(fn () => Q.Cons(seed,
              loop(n-1)(D.delay(fn () => Int.rem(77*D.force seed+1,1024)))))
    in loop count (value 1967)end
  fun sorted delete count = toList delete (make(randoms count))
end
