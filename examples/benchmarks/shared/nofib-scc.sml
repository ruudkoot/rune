(* Launchbury's two list-based DFS passes, with demand-specific finish lists. *)
functor BenchSccFn(D : BENCH_SUSPEND) =
struct
  structure Q = BenchCellSequenceFn(D)
  fun range edges vertex = D.delay(fn () =>
    case edges of [] => Q.Nil
    | (from,dest)::rest => if from=vertex then Q.Cons(Q.value dest,range rest vertex)
        else D.force(range rest vertex))
  fun member (x : int) = List.exists(fn y => x=y)
  fun dfs neighbours (visited,finished) vertices =
    let val result = D.delay(fn () => case D.force vertices of Q.Nil => (visited,finished)
          | Q.Cons(cell,rest) =>
              let val x = D.force cell
              in if member x (D.force visited) then dfs neighbours (visited,finished) rest else
                let val child = D.delay(fn () => dfs neighbours (Q.value(x::D.force visited),Q.empty()) (neighbours x))
                    val seen = D.delay(fn () => D.force(#1(D.force child)))
                    val childFinish = D.delay(fn () => D.force(#2(D.force child)))
                    val finish = Q.append(Q.cons(Q.value x)childFinish)finished
                in dfs neighbours (seen,finish) rest end
              end)
    in (D.delay(fn () => D.force(#1(D.force result))),
        D.delay(fn () => D.force(#2(D.force result)))) end
  fun spanning neighbours (visited,components) vertices =
    let val result = D.delay(fn () => case D.force vertices of Q.Nil => (visited,components)
          | Q.Cons(cell,rest) =>
              let val x = D.force cell
              in if member x (D.force visited) then spanning neighbours (visited,components) rest else
                let val child = D.delay(fn () => dfs neighbours (Q.value(x::D.force visited),Q.empty()) (neighbours x))
                    val seen = D.delay(fn () => D.force(#1(D.force child)))
                    val finished = D.delay(fn () => D.force(#2(D.force child)))
                    val component = Q.cons(Q.value x)finished
                in spanning neighbours (seen,Q.cons(Q.value component)components) rest end
              end)
    in (D.delay(fn () => D.force(#1(D.force result))),
        D.delay(fn () => D.force(#2(D.force result)))) end
  fun components edges vertices =
    let val reversed = List.map(fn (x,y) => (y,x))edges
        val (_,finished) = dfs(range edges)(Q.value [],Q.empty())(Q.fromList vertices)
        val (_,groups) = spanning(range reversed)(Q.value [],Q.empty())finished
    in List.map Q.toList(Q.toList groups) end
  val vertices = [1,2,3,4,5,6,7]
  val edges = [(2,1),(3,2),(3,4),(3,7),(4,3),(5,1),(5,6),(5,7),(6,5),(7,6)]
  fun render groups = "[" ^ String.concatWith "," (List.map(fn group =>
    "[" ^ String.concatWith "," (List.map Int.toString group) ^ "]")groups) ^ "]"
end
