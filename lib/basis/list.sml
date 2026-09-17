(* List *)
structure List =
struct
  datatype list = datatype list
  exception Empty = Empty

  fun null [] = true
    | null _ = false

  fun hd (x :: _) = x
    | hd [] = raise Empty

  fun tl (_ :: xs) = xs
    | tl [] = raise Empty

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

  and length l =
    let fun go ([], n) = n
          | go (_ :: xs, n) = go (xs, n + 1)
    in go (l, 0) end

  and rev l =
    let fun go ([], acc) = acc
          | go (x :: xs, acc) = go (xs, x :: acc)
    in go (l, []) end

  fun revAppend ([], ys) = ys
    | revAppend (x :: xs, ys) = revAppend (xs, x :: ys)

  fun [] @ ys = ys
    | (x :: xs) @ ys = x :: (xs @ ys)

  fun concat [] = []
    | concat (l :: ls) = l @ concat ls

  fun app f [] = ()
    | app f (x :: xs) = (f x; app f xs)

  fun map f [] = []
    | map f (x :: xs) = f x :: map f xs

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

  fun foldl f init [] = init
    | foldl f init (x :: xs) = foldl f (f (x, init)) xs

  fun foldr f init [] = init
    | foldr f init (x :: xs) = f (x, foldr f init xs)

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
