(* Implements: HS_STRING_MAP *)
structure HsStringMap :> HS_STRING_MAP =
struct
  datatype color = Red | Black
  datatype 'a map = Leaf | Node of color * 'a map * string * 'a * 'a map

  val empty = Leaf

  fun balance (Black, Node (Red, Node (Red, a, xk, xv, b), yk, yv, c), zk, zv, d) =
        Node (Red, Node (Black, a, xk, xv, b), yk, yv, Node (Black, c, zk, zv, d))
    | balance (Black, Node (Red, a, xk, xv, Node (Red, b, yk, yv, c)), zk, zv, d) =
        Node (Red, Node (Black, a, xk, xv, b), yk, yv, Node (Black, c, zk, zv, d))
    | balance (Black, a, xk, xv, Node (Red, Node (Red, b, yk, yv, c), zk, zv, d)) =
        Node (Red, Node (Black, a, xk, xv, b), yk, yv, Node (Black, c, zk, zv, d))
    | balance (Black, a, xk, xv, Node (Red, b, yk, yv, Node (Red, c, zk, zv, d))) =
        Node (Red, Node (Black, a, xk, xv, b), yk, yv, Node (Black, c, zk, zv, d))
    | balance (c, a, k, v, b) = Node (c, a, k, v, b)

  fun insert (m, k, v) =
    let
      fun ins Leaf = Node (Red, Leaf, k, v, Leaf)
        | ins (Node (c, a, k', v', b)) =
            if String.< (k, k') then balance (c, ins a, k', v', b)
            else if String.< (k', k) then balance (c, a, k', v', ins b)
            else Node (c, a, k, v, b)
    in
      case ins m of
        Node (_, a, k', v', b) => Node (Black, a, k', v', b)
      | Leaf => Leaf
    end

  fun find (Leaf, _) = NONE
    | find (Node (_, a, k', v, b), k) =
        if String.< (k, k') then find (a, k) else if String.< (k', k) then find (b, k) else SOME v

  fun member (m, k) = isSome (find (m, k))

  fun foldl f init m =
    let
      fun go (Leaf, acc) = acc
        | go (Node (_, a, k, v, b), acc) = go (b, f (k, v, go (a, acc)))
    in
      go (m, init)
    end

  fun listItems m = List.rev (foldl (fn (k, v, acc) => (k, v) :: acc) [] m)

  fun size m = foldl (fn (_, _, n) => n + 1) 0 m
end
