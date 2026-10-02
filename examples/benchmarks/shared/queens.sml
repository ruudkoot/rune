(* nofib imaginary/queens: preserve board-first comprehension order, column
   ordering, safety short-circuiting and suffix sharing in both variants. *)
structure BenchQueens =
struct
  fun safe _ _ [] = true
    | safe x d (q::qs) =
        x <> q andalso x <> q+d andalso x <> q-d andalso safe x (d+1) qs
  fun strict size =
    let
      fun gen 0 = [[]]
        | gen n =
            List.concat (List.map (fn board =>
              List.mapPartial (fn q => if safe q 1 board then SOME (q::board) else NONE)
                (List.tabulate (size,fn i => i+1))) (gen (n-1)))
    in List.length (gen size) end
  datatype 'a stream = Nil | Cons of 'a * 'a stream BenchLazy.delay
  fun lazy size =
    let
      fun expand Nil = Nil
        | expand (Cons(board,rest)) = candidates 1 board rest
      and candidates q board rest =
        if q > size then expand (BenchLazy.force rest)
        else if safe q 1 board then
          Cons (q::board,BenchLazy.delay (fn () => candidates (q+1) board rest))
        else candidates (q+1) board rest
      fun gen 0 = Cons ([],BenchLazy.delay (fn () => Nil))
        | gen n = expand (gen (n-1))
      fun count (Nil,n) = n
        | count (Cons(_,rest),n) = count (BenchLazy.force rest,n+1)
    in count (gen size,0) end
end
