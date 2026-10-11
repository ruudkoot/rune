(* The second implementation of BigInt, on lists alone: a sign and the
   digits in base 10000, the least significant first; zero has no digits
   and is not negative. *)
_export structure BigInt : BIGINT =
struct
  val base = 10000
  type int = bool * Int.int list

  fun dropZeros (0 :: ds) = dropZeros ds
    | dropZeros ds = ds
  fun make (neg, ds) = case List.rev (dropZeros (List.rev ds)) of [] => (false, []) | ds => (neg, ds)

  (* the digits of |n|, without negating n, which may be the least int *)
  fun digitsOf 0 = []
    | digitsOf n = Int.abs (Int.rem (n, base)) :: digitsOf (Int.quot (n, base))
  fun fromInt n = make (n < 0, digitsOf n)

  fun split [] = (0, [])
    | split (d :: ds) = (d, ds)
  fun addMag ([], [], 0) = []
    | addMag ([], [], c) = [c]
    | addMag (xs, ys, c) =
        let val (x, xs) = split xs val (y, ys) = split ys val s = x + y + c
        in s mod base :: addMag (xs, ys, s div base) end
  (* xs - ys, where xs is at least ys *)
  fun subMag ([], [], _) = []
    | subMag (xs, ys, b) =
        let val (x, xs) = split xs val (y, ys) = split ys val d = x - y - b
        in if d < 0 then d + base :: subMag (xs, ys, 1) else d :: subMag (xs, ys, 0) end
  fun compareMag (xs, ys) =
    case Int.compare (length xs, length ys) of
      EQUAL => List.foldl (fn ((x, y), EQUAL) => Int.compare (x, y) | (_, r) => r) EQUAL
                          (List.rev (ListPair.zip (xs, ys)))
    | r => r
  fun scale (xs, k) =
    let fun go ([], c) = if c = 0 then [] else [c]
          | go (x :: xs, c) = let val p = x * k + c in p mod base :: go (xs, p div base) end
    in go (xs, 0) end
  fun mulMag ([], _) = []
    | mulMag (x :: xs, ys) = addMag (scale (ys, x), 0 :: mulMag (xs, ys), 0)

  fun compare ((an, ax), (bn, bx)) =
    case (an, bn) of
      (false, true) => GREATER
    | (true, false) => LESS
    | (false, false) => compareMag (ax, bx)
    | (true, true) => compareMag (bx, ax)
  fun pad d = let val s = Int.toString d in CharVector.tabulate (4 - size s, fn _ => #"0") ^ s end
  fun toString (_, []) = "0"
    | toString (neg, ds) =
        let val r = List.rev ds
        in (if neg then "~" else "") ^ Int.toString (hd r) ^ String.concat (List.map pad (tl r)) end

  fun (an, ax) + (bn, bx) =
    if an = bn then make (an, addMag (ax, bx, 0))
    else case compareMag (ax, bx) of
           LESS => make (bn, subMag (bx, ax, 0))
         | _ => make (an, subMag (ax, bx, 0))
  fun (an, ax) * (bn, bx) = make (an <> bn, mulMag (ax, bx))
end
