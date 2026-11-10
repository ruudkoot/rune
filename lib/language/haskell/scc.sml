(* Implements: HS_SCC *)
structure HsScc :> HS_SCC =
struct
  structure M = HsStringMap

  (* Tarjan's algorithm: a component is complete once its root is *)
  fun sccs (nodes : string list, edges : string -> string list) =
    let
      val position = #2 (List.foldl (fn (n, (k, m)) => (k + 1, M.insert (m, n, k))) (0, M.empty) nodes)
      val index : int M.map ref = ref M.empty
      val low : int M.map ref = ref M.empty
      val onStack : bool M.map ref = ref M.empty
      val stack : string list ref = ref []
      val counter = ref 0
      val out : string list list ref = ref []
      fun get (m, k) = valOf (M.find (!m, k))
      fun connect v =
        let
          val () = (index := M.insert (!index, v, !counter); low := M.insert (!low, v, !counter);
                    counter := !counter + 1; stack := v :: !stack; onStack := M.insert (!onStack, v, true))
          fun edge w =
            if not (M.member (position, w)) then ()
            else if not (M.member (!index, w)) then (connect w; low := M.insert (!low, v, Int.min (get (low, v), get (low, w))))
            else if M.find (!onStack, w) = SOME true then low := M.insert (!low, v, Int.min (get (low, v), get (index, w)))
            else ()
          val () = List.app edge (edges v)
        in
          if get (low, v) = get (index, v) then
            let
              fun pop acc =
                case !stack of
                  w :: rest => (stack := rest; onStack := M.insert (!onStack, w, false); if w = v then w :: acc else pop (w :: acc))
                | [] => acc
              val members = pop []
              fun earlier (a, b) = get' a < get' b
              and get' n = valOf (M.find (position, n))
              fun insert (x, []) = [x]
                | insert (x, y :: ys) = if earlier (x, y) then x :: y :: ys else y :: insert (x, ys)
            in
              out := List.foldl insert [] members :: !out
            end
          else ()
        end
    in
      List.app (fn v => if M.member (!index, v) then () else connect v) nodes;
      List.rev (!out)
    end
end
