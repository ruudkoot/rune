(* The history of runs: a table by path, read and written as TSV. *)
structure History :> HISTORY =
struct
  type entry = {path : string, walls : real list, passed : bool, flips : int}

  (* by path, in an AVL tree of strings, each node with its height: a
     history is read in the order of its paths, which would make a plain
     tree a list *)
  datatype history = Leaf | Node of history * entry * history * int

  val empty = Leaf

  fun height Leaf = 0
    | height (Node (_, _, _, h)) = h
  fun node (l, e, r) = Node (l, e, r, 1 + Int.max (height l, height r))
  fun rotateRight (Node (Node (a, x, b, _), y, c, _)) = node (a, x, node (b, y, c))
    | rotateRight t = t
  fun rotateLeft (Node (a, x, Node (b, y, c, _), _)) = node (node (a, x, b), y, c)
    | rotateLeft t = t
  fun balance (l, e, r) =
    let val d = height l - height r
    in
      if d > 1 then
        (case l of
           Node (ll, _, lr, _) => rotateRight (node (if height lr > height ll then rotateLeft l else l, e, r))
         | Leaf => node (l, e, r))
      else if d < ~1 then
        (case r of
           Node (rl, _, rr, _) => rotateLeft (node (l, e, if height rl > height rr then rotateRight r else r))
         | Leaf => node (l, e, r))
      else node (l, e, r)
    end

  fun find (Leaf, _) = NONE
    | find (Node (l, e, r, _), p) =
        case String.compare (p, #path e) of LESS => find (l, p) | GREATER => find (r, p) | EQUAL => SOME e

  fun insert (Leaf, e) = node (Leaf, e, Leaf)
    | insert (Node (l, x, r, h), e) =
        case String.compare (#path e, #path x) of
          LESS => balance (insert (l, e), x, r)
        | GREATER => balance (l, x, insert (r, e))
        | EQUAL => Node (l, e, r, h)

  fun entries h =
    let fun go (Leaf, acc) = acc | go (Node (l, e, r, _), acc) = go (l, e :: go (r, acc)) in go (h, []) end

  fun record (h, {path, wall, passed}) =
    case find (h, path) of
      NONE => insert (h, {path = path, walls = [wall], passed = passed, flips = 0})
    | SOME {walls, passed = earlier, flips, ...} =>
        insert (h, {path = path, walls = List.take (wall :: walls, Int.min (5, 1 + length walls)), passed = passed,
                    flips = if earlier = passed then flips else flips + 1})

  fun cost (h, p) =
    case find (h, p) of
      SOME {walls = w :: ws, ...} => SOME (List.foldl Real.max w ws)
    | _ => NONE

  fun failedLast (h, p) = case find (h, p) of SOME {passed, ...} => not passed | NONE => false

  (* path, walls joined by commas, 1 or 0, flips *)
  fun line ({path, walls, passed, flips} : entry) =
    path ^ "\t" ^ String.concatWith "," (List.map (Real.fmt (StringCvt.FIX (SOME 3))) walls) ^ "\t"
    ^ (if passed then "1" else "0") ^ "\t" ^ Int.toString flips ^ "\n"

  fun parse l =
    case String.fields (fn c => c = #"\t") l of
      [path, walls, passed, flips] =>
        (case (List.mapPartial Real.fromString (String.tokens (fn c => c = #",") walls), Int.fromString flips) of
           (ws, SOME f) => SOME {path = path, walls = ws, passed = passed = "1", flips = f}
         | _ => NONE)
    | _ => NONE

  fun read file =
    let
      val s = TextIO.openIn file
      fun go h = case TextIO.inputLine s of
                   NONE => h
                 | SOME l => go (case parse (String.substring (l, 0, size l - 1)) of SOME e => insert (h, e) | NONE => h)
    in go Leaf before TextIO.closeIn s end
    handle IO.Io _ => Leaf

  fun write (file, h) =
    let
      val tmp = file ^ ".new"
      val s = TextIO.openOut tmp
    in
      List.app (fn e => TextIO.output (s, line e)) (entries h);
      TextIO.closeOut s;
      OS.FileSys.rename {old = tmp, new = file}
    end
end
