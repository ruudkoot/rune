(* Kevin's award selection and Augustsson's stable quicksort. *)
functor BenchAwardsFn(D : BENCH_SUSPEND) =
struct
  structure Q = BenchCellSequenceFn(D)
  fun filter predicate xs = D.delay(fn () => case D.force xs of Q.Nil => Q.Nil
    | Q.Cons(x,rest) => if predicate(D.force x) then Q.Cons(x,filter predicate rest)
        else D.force(filter predicate rest))
  fun permutations _ [] = Q.empty()
    | permutations 1 scores = Q.map(fn n => [n])(Q.fromList scores)
    | permutations n (x::xs) =
        Q.append(Q.map(fn rest => x::rest)(permutations(n-1)xs))(permutations n xs)
  fun fromCells xs = D.delay(fn () => case xs of [] => Q.Nil
    | x::rest => Q.Cons(x,fromCells rest))
  fun sortLe le input =
    let
      fun qsort xs finish = D.delay(fn () => case D.force xs of Q.Nil => D.force finish
        | Q.Cons(x,rest) => case D.force rest of Q.Nil => Q.Cons(x,finish)
          | _ => D.force(qpart x rest [] [] finish))
      and qpart x xs less greater finish = D.delay(fn () => case D.force xs of
          Q.Nil => D.force(rqsort(fromCells less)(Q.cons x (rqsort(fromCells greater)finish)))
        | Q.Cons(y,ys) => if le(D.force x,D.force y) then D.force(qpart x ys less (y::greater)finish)
            else D.force(qpart x ys (y::less)greater finish))
      and rqsort xs finish = D.delay(fn () => case D.force xs of Q.Nil => D.force finish
        | Q.Cons(x,rest) => case D.force rest of Q.Nil => Q.Cons(x,finish)
          | _ => D.force(rqpart x rest [] [] finish))
      and rqpart x xs lesser greater finish = D.delay(fn () => case D.force xs of
          Q.Nil => D.force(qsort(fromCells lesser)(Q.cons x (qsort(fromCells greater)finish)))
        | Q.Cons(y,ys) => if le(D.force y,D.force x) then D.force(rqpart x ys (y::lesser)greater finish)
            else D.force(rqpart x ys lesser (y::greater)finish))
    in qsort input (Q.empty()) end
  fun listCompare ([] : int list,[]) = EQUAL
    | listCompare([],_) = LESS
    | listCompare(_,[]) = GREATER
    | listCompare(x::xs,y::ys) = case Int.compare(x,y) of EQUAL => listCompare(xs,ys) | order => order
  fun le ((sum,items),(otherSum,otherItems)) =
    case Int.compare(D.force sum,D.force otherSum) of
      LESS => true | GREATER => false | EQUAL => listCompare(items,otherItems)<>GREATER
  fun awards scores =
    let val sums = Q.map(fn items => (D.delay(fn () => List.foldl op + 0 items),items))(permutations 3 scores)
        fun award name threshold = Q.map(fn candidate => (name,candidate))
          (sortLe le (filter(fn (sum,_) => D.force sum>=threshold)sums))
    in Q.append(award "Gold" 70)(Q.append(award "Silver" 60)(award "Bronze" 50)) end
  fun removeFirst (_ : int) [] = []
    | removeFirst x (y::ys) = if x=y then ys else y::removeFirst x ys
  fun difference scores used = List.foldl(fn (value,rest) => removeFirst value rest)scores used
  fun findAwards input = D.delay(fn () =>
    let val scores = D.force input
        val options = awards scores
    in case D.force options of Q.Nil => Q.Nil
      | Q.Cons(first,_) =>
          Q.Cons(first,findAwards(D.delay(fn () => difference scores (#2(#2(D.force first))))))
    end)
  fun competitors i =
    [("Simon",[35,27,40,i,34,21]),("Hans",[23,19,45,i,17,10,5,8,14]),
     ("Phil",[1,18,i,20,21,19,34,8,16,21]),("Kevin",[9,23,17,54,i,41,9,18,14])]
  fun render i =
    let fun triple (name,(sum,items)) = "(\"" ^ name ^ "\",(" ^ Int.toString(D.force sum) ^ ",[" ^
              String.concatWith "," (List.map Int.toString items) ^ "]))"
        fun person (name,scores) = "(\"" ^ name ^ "\",[" ^
              String.concatWith "," (List.map triple (Q.toList(findAwards(Q.value scores)))) ^ "])"
    in "[" ^ String.concatWith "," (List.map person(competitors i)) ^ "]" end
end
