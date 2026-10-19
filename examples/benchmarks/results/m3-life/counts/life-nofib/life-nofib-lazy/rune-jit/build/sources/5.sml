(* John Launchbury's finite list-grid, zero borders, and adjacent-fixpoint stop. *)
functor BenchNofibLifeFn (D : BENCH_SUSPEND) =
struct
  structure Q = BenchCellSequenceFn(D)
  type row = int Q.sequence
  type board = row Q.sequence
  fun shift zero xs = Q.zip3 (Q.cons zero (Q.init xs)) xs
    (Q.append(Q.delayedTail xs)(Q.cons zero (Q.empty())))
  fun element ((a,b,c),(d,e,f),(g,h,i)) =
    let val total = D.force a+D.force b+D.force c+D.force d+D.force f+D.force g+D.force h+D.force i
    in if total<2 orelse total>3 then 0 else if total=3 then 1 else D.force e end
  fun row (last,current,next) = Q.zipWith3 element
    (shift(Q.value 0)(Q.fromCell last)) (shift(Q.value 0)(Q.fromCell current))
    (shift(Q.value 0)(Q.fromCell next))
  fun generation n board =
    Q.map row (shift (Q.value(Q.replicate n (Q.value 0))) board)
  val pattern = [0,0,0,1,1,1,1,1,0,1,1,1,1,1,0,1,1,1,1,1,0,1,1,1,1,1,0]
  fun initial n =
    let val rows = List.tabulate(15,fn i => if i=14 then pattern else [])
        val start = Q.map(fn row => Q.take n (Q.append(Q.fromList row)(Q.replicate n (Q.value 0))))(Q.fromList rows)
        val padding = Q.replicate n (Q.value(Q.replicate n (Q.value 0)))
    in Q.take n (Q.append start padding) end
  fun fixpoint n =
    let fun limit index board =
          let val next = generation n board
          in if Q.equal(fn (left,right) => Q.equal(fn (x:int,y) => x=y) left right)board next then (index,board)
             else limit(index+1)next end
    in limit 0 (initial n) end
  fun render (index,board) =
    let fun star 0 = "  " | star 1 = " o" | star _ = raise Fail "invalid Life cell"
        val rows = List.map(fn row => String.concat(List.map star(Q.toList row))^"\n")(Q.toList board)
    in Int.toString index ^ "\n\n" ^ String.concat rows end
end
