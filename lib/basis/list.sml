(* List *)
structure List =
struct
  datatype list = datatype list
  exception Empty = Empty

  (* from the top-level environment (pervasive.sml) *)
  val null = null
  val hd = hd
  val tl = tl
  val length = length
  val rev = rev
  val op @ = op @
  val app = app
  val map = map
  val foldl = foldl
  val foldr = foldr

  fun last [x] = x
    | last (_ :: xs) = last xs
    | last [] = raise Empty

  fun getItem [] = NONE
    | getItem (x :: xs) = SOME (x, xs)

  fun nth (l, n) =
    let
      fun go (x :: _, 0) = x
        | go (_ :: xs, n) = go (xs, n - 1)
        | go ([], _) = raise Subscript
    in
      if n < 0 then raise Subscript else go (l, n)
    end

  fun take (l, n) =
    let
      fun go (_, 0, acc) = rev acc
        | go (x :: xs, n, acc) = go (xs, n - 1, x :: acc)
        | go ([], _, _) = raise Subscript
    in
      if n < 0 then raise Subscript else go (l, n, [])
    end

  and drop (l, n) =
    let
      fun go (l, 0) = l
        | go (_ :: xs, n) = go (xs, n - 1)
        | go ([], _) = raise Subscript
    in
      if n < 0 then raise Subscript else go (l, n)
    end


  fun revAppend ([], ys) = ys
    | revAppend (x :: xs, ys) = revAppend (xs, x :: ys)

  fun concat [] = []
    | concat (l :: ls) = l @ concat ls

  fun mapPartial f [] = []
    | mapPartial f (x :: xs) =
      case f x of
        NONE => mapPartial f xs
      | SOME y => y :: mapPartial f xs

  fun find p [] = NONE
    | find p (x :: xs) = if p x then SOME x else find p xs

  fun filter p [] = []
    | filter p (x :: xs) = if p x then x :: filter p xs else filter p xs

  fun partition p l =
    let
      fun go ([], yes, no) = (rev yes, rev no)
        | go (x :: xs, yes, no) = if p x then go (xs, x :: yes, no) else go (xs, yes, x :: no)
    in go (l, [], []) end

  fun exists p [] = false
    | exists p (x :: xs) = p x orelse exists p xs

  fun all p [] = true
    | all p (x :: xs) = p x andalso all p xs

  fun tabulate (n, f) =
    let fun go i = if i >= n then [] else f i :: go (i + 1)
    in if n < 0 then raise Size else go 0 end

  fun collate cmp ([], []) = EQUAL
    | collate cmp ([], _) = LESS
    | collate cmp (_, []) = GREATER
    | collate cmp (x :: xs, y :: ys) =
      case cmp (x, y) of
        EQUAL => collate cmp (xs, ys)
      | other => other
end
