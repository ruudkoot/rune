(* Maps keyed by a string, for the scopes of CoreLint and CoreInterp: a
   red-black tree (Okasaki), with no deletion. *)
structure CoreMap =
struct
  datatype color = Red | Black
  datatype 'a map = Empty | Node of color * 'a map * string * 'a * 'a map

  val empty = Empty

  fun find (Empty, _) = NONE
    | find (Node (_, l, k, v, r), x) =
        case String.compare (x, k) of
          LESS => find (l, x)
        | GREATER => find (r, x)
        | EQUAL => SOME v

  fun balance (Black, Node (Red, Node (Red, a, xk, xv, b), yk, yv, c), zk, zv, d) =
        Node (Red, Node (Black, a, xk, xv, b), yk, yv, Node (Black, c, zk, zv, d))
    | balance (Black, Node (Red, a, xk, xv, Node (Red, b, yk, yv, c)), zk, zv, d) =
        Node (Red, Node (Black, a, xk, xv, b), yk, yv, Node (Black, c, zk, zv, d))
    | balance (Black, a, xk, xv, Node (Red, Node (Red, b, yk, yv, c), zk, zv, d)) =
        Node (Red, Node (Black, a, xk, xv, b), yk, yv, Node (Black, c, zk, zv, d))
    | balance (Black, a, xk, xv, Node (Red, b, yk, yv, Node (Red, c, zk, zv, d))) =
        Node (Red, Node (Black, a, xk, xv, b), yk, yv, Node (Black, c, zk, zv, d))
    | balance (c, l, k, v, r) = Node (c, l, k, v, r)

  (* m with x bound to v, in place of what x was bound to *)
  fun insert (m, x, v) =
    let
      fun ins Empty = Node (Red, Empty, x, v, Empty)
        | ins (Node (c, l, k, w, r)) =
            case String.compare (x, k) of
              LESS => balance (c, ins l, k, w, r)
            | GREATER => balance (c, l, k, w, ins r)
            | EQUAL => Node (c, l, x, v, r)
    in
      case ins m of
        Node (_, l, k, w, r) => Node (Black, l, k, w, r)
      | Empty => Empty
    end

  fun member (m, x) = isSome (find (m, x))
end
