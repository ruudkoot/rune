(* The history of runs: a table by path, read and written as TSV. *)
structure History :> HISTORY =
struct
  type entry = {path : string, walls : real list, passed : bool, flips : int}

  (* by path, in the order of a binary tree of strings *)
  datatype history = Leaf | Node of history * entry * history

  val empty = Leaf

  fun find (Leaf, _) = NONE
    | find (Node (l, e, r), p) =
        case String.compare (p, #path e) of LESS => find (l, p) | GREATER => find (r, p) | EQUAL => SOME e

  fun insert (Leaf, e) = Node (Leaf, e, Leaf)
    | insert (Node (l, x, r), e) =
        case String.compare (#path e, #path x) of
          LESS => Node (insert (l, e), x, r)
        | GREATER => Node (l, x, insert (r, e))
        | EQUAL => Node (l, e, r)

  fun entries h =
    let fun go (Leaf, acc) = acc | go (Node (l, e, r), acc) = go (l, e :: go (r, acc)) in go (h, []) end

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
