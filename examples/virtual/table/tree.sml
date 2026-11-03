(* The second implementation of Table: a balanced tree (AVL), each node
   with its height. *)
_export functor Table (K : KEY) : TABLE where type key = K.t =
struct
  type key = K.t
  datatype 'a tree = Leaf | Node of 'a tree * key * 'a * 'a tree * int
  type 'a table = 'a tree
  exception Missing of key
  val empty = Leaf

  fun height Leaf = 0
    | height (Node (_, _, _, _, h)) = h
  fun node (l, k, v, r) = Node (l, k, v, r, 1 + Int.max (height l, height r))
  fun rotateRight (Node (Node (a, k1, v1, b, _), k2, v2, c, _)) = node (a, k1, v1, node (b, k2, v2, c))
    | rotateRight t = t
  fun rotateLeft (Node (a, k1, v1, Node (b, k2, v2, c, _), _)) = node (node (a, k1, v1, b), k2, v2, c)
    | rotateLeft t = t
  (* a node whose subtrees' heights differ by two at most, made to differ by one *)
  fun balance (l, k, v, r) =
    let val d = height l - height r
    in
      if d > 1 then
        (case l of
           Node (ll, _, _, lr, _) => if height lr > height ll then rotateRight (node (rotateLeft l, k, v, r))
                                     else rotateRight (node (l, k, v, r))
         | Leaf => node (l, k, v, r))
      else if d < ~1 then
        (case r of
           Node (rl, _, _, rr, _) => if height rl > height rr then rotateLeft (node (l, k, v, rotateRight r))
                                     else rotateLeft (node (l, k, v, r))
         | Leaf => node (l, k, v, r))
      else node (l, k, v, r)
    end

  fun insert (Leaf, k, v) = node (Leaf, k, v, Leaf)
    | insert (Node (l, k', v', r, h), k, v) =
        case K.compare (k, k') of
          LESS => balance (insert (l, k, v), k', v', r)
        | EQUAL => Node (l, k, v, r, h)
        | GREATER => balance (l, k', v', insert (r, k, v))
  fun find (Leaf, _) = NONE
    | find (Node (l, k', v, r, _), k) =
        case K.compare (k, k') of
          LESS => find (l, k)
        | EQUAL => SOME v
        | GREATER => find (r, k)
  fun get (t, k) = case find (t, k) of SOME v => v | NONE => raise Missing k
  fun size Leaf = 0
    | size (Node (l, _, _, r, _)) = size l + 1 + size r
  fun toList t =
    let fun go (Leaf, acc) = acc
          | go (Node (l, k, v, r, _), acc) = go (l, (k, v) :: go (r, acc))
    in go (t, []) end
end
