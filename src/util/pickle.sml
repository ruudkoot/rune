(* Bytes for what the compiler keeps between compiles (the incremental
   roadmap's M6): a writer that gathers them and a reader that takes them
   apart, of numbers, strings, lists and options; and the hash that names a
   content. A number is a varint, a natural one as itself and any other
   zigzagged, so that it costs a byte below 128 or 64; every number written
   is far below 2^29, which every host's int holds doubled. *)
structure Pickle =
struct
  exception Bad of string

  (* ---- writing ---- *)

  type writer = string list ref   (* the chunks, newest first *)

  fun writer () : writer = ref []
  fun contents (w : writer) : string = String.concat (List.rev (!w))
  fun bytes (w : writer, s : string) = w := s :: !w

  fun byte (w : writer, n : int) = w := String.str (Char.chr n) :: !w

  fun nat (w : writer, n : int) =
    if n < 0 then raise Fail "Pickle.nat: a negative number"
    else if n < 128 then byte (w, n)
    else (byte (w, 128 + n mod 128); nat (w, n div 128))

  fun int (w : writer, n : int) = nat (w, if n >= 0 then 2 * n else ~2 * n - 1)

  fun bool (w : writer, b : bool) = byte (w, if b then 1 else 0)

  fun string (w : writer, s : string) = (nat (w, String.size s); bytes (w, s))

  fun list (f : writer * 'a -> unit) (w : writer, xs : 'a list) =
    (nat (w, List.length xs); List.app (fn x => f (w, x)) xs)

  fun option (f : writer * 'a -> unit) (w : writer, x : 'a option) =
    case x of NONE => byte (w, 0) | SOME v => (byte (w, 1); f (w, v))

  (* ---- reading ---- *)

  type reader = {s : string, pos : int ref}

  fun reader (s : string) : reader = {s = s, pos = ref 0}
  fun atEnd ({s, pos} : reader) = !pos >= String.size s

  fun rbyte ({s, pos} : reader) : int =
    if !pos >= String.size s then raise Bad "cut short"
    else Char.ord (String.sub (s, !pos)) before pos := !pos + 1

  fun rnat (r : reader) : int =
    let
      (* at most five bytes: 35 bits, of which a host of 31 bits holds what
         a writer wrote *)
      fun go (scale, acc, k) =
        let val b = rbyte r
        in
          if b < 128 then acc + scale * b
          else if k = 4 then raise Bad "a number out of range"
          else go (scale * 128, acc + scale * (b - 128), k + 1)
        end
    in go (1, 0, 0) end

  fun rint (r : reader) : int =
    let val n = rnat r in if n mod 2 = 0 then n div 2 else ~((n + 1) div 2) end

  fun rbool (r : reader) : bool =
    case rbyte r of 0 => false | 1 => true | _ => raise Bad "not a bool"

  fun rbytes ({s, pos} : reader, n : int) : string =
    if n < 0 orelse !pos + n > String.size s then raise Bad "cut short"
    else String.substring (s, !pos, n) before pos := !pos + n

  fun rstring (r : reader) : string = rbytes (r, rnat r)

  fun rlist (f : reader -> 'a) (r : reader) : 'a list =
    let
      val n = rnat r
      fun go (0, acc) = List.rev acc
        | go (k, acc) = go (k - 1, f r :: acc)
    in go (n, []) end

  fun roption (f : reader -> 'a) (r : reader) : 'a option =
    case rbyte r of 0 => NONE | 1 => SOME (f r) | _ => raise Bad "not an option"

  (* ---- the hash of a content: four independent hashes of 24 bits each,
     96 bits in 24 hexadecimal digits, which a host of 31-bit ints works
     out as well as any other ---- *)
  fun hash (s : string) : string =
    let
      val n = String.size s
      (* one pass, the four at once: a * 43 + 255 is below 2^31 *)
      fun go (i, a, b, c, d) =
        if i = n then (a, b, c, d)
        else
          let val x = Char.ord (String.sub (s, i))
          in go (i + 1, (a * 31 + x) mod 16777213, (b * 37 + x) mod 16777199, (c * 41 + x) mod 16777183,
                 (d * 43 + x) mod 16777153)
          end
      val (a, b, c, d) = go (0, 7, 11, 13, 17)
      fun hex6 n = StringCvt.padLeft #"0" 6 (Int.fmt StringCvt.HEX n)
    in
      String.map Char.toLower (hex6 a ^ hex6 b ^ hex6 c ^ hex6 d)
    end
end
