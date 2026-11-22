(* Strongly connected components, for HsLint's dependency analyses (the
   haskell98 roadmap's M16): the groups of type constructors and classes
   whose kinds are inferred together (4.6), and the declaration groups of
   bindings (4.5.1). Tarjan's algorithm, which gives each component after
   every component it reaches, so that a group comes after those it
   depends on; within a group the nodes keep the order of their numbers. *)
structure HsLintScc =
struct
  (* `groups (n, succs)`: the components of the graph of nodes 0 to n - 1,
     where `succs i` is what node `i` depends on, dependencies first *)
  fun groups (n : int, succs : int -> int list) : int list list =
    let
      val index = Array.array (n, ~1)
      val low = Array.array (n, 0)
      val onStack = Array.array (n, false)
      val stack : int list ref = ref []
      val counter = ref 0
      val out : int list list ref = ref []
      fun sort xs =
        let
          fun insert (x, []) = [x]
            | insert (x, y :: ys) = if x <= y then x :: y :: ys else y :: insert (x, ys)
        in
          List.foldl insert [] xs
        end
      fun visit v =
        let
          val () = Array.update (index, v, !counter)
          val () = Array.update (low, v, !counter)
          val () = counter := !counter + 1
          val () = stack := v :: !stack
          val () = Array.update (onStack, v, true)
          fun edge w =
            if Array.sub (index, w) < 0 then
              (visit w; Array.update (low, v, Int.min (Array.sub (low, v), Array.sub (low, w))))
            else if Array.sub (onStack, w) then
              Array.update (low, v, Int.min (Array.sub (low, v), Array.sub (index, w)))
            else ()
          val () = List.app edge (succs v)
        in
          if Array.sub (low, v) = Array.sub (index, v) then
            let
              fun pop acc =
                case !stack of
                  w :: rest =>
                    (stack := rest; Array.update (onStack, w, false);
                     if w = v then w :: acc else pop (w :: acc))
                | [] => acc
            in
              out := sort (pop []) :: !out
            end
          else ()
        end
      fun all i = if i >= n then () else (if Array.sub (index, i) < 0 then visit i else (); all (i + 1))
    in
      all 0;
      List.rev (!out)
    end

  (* whether node `i` of a group depends on itself *)
  fun selfLoop (succs : int -> int list) i = List.exists (fn j => j = i) (succs i)
end
