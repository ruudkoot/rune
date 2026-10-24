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
    in go (1, 0, 0) handle Overflow => raise Bad "a number out of range" end

  fun rint (r : reader) : int =
    let val n = rnat r in if n mod 2 = 0 then n div 2 else ~(n div 2) - 1 end

  fun rbool (r : reader) : bool =
    case rbyte r of 0 => false | 1 => true | _ => raise Bad "not a bool"

  fun rbytes ({s, pos} : reader, n : int) : string =
    if n < 0 orelse n > String.size s - !pos then raise Bad "cut short"
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

  (* What was hashed, for --pass-stats=hash: while counting, each hash
     adds its bytes to its label's, the place that hashed them (UnitBasis
     sets it), and one to its count *)
  val counting = ref false
  val () = CompilerState.cellRoot ("Pickle.counting", counting)
  val label = ref "other"
  val () = CompilerState.cellRoot ("Pickle.label", label)
  val counted : (string * int * int) list ref = ref []     (* label, bytes, hashes *)
  val () = CompilerState.cellRoot ("Pickle.counted", counted)
  fun count (n : int) : unit =
    let
      val l = !label
      fun add [] = [(l, n, 1)]
        | add ((k, b, c) :: rest) = if k = l then (k, b + n, c + 1) :: rest else (k, b, c) :: add rest
    in counted := add (!counted) end

  (* the four at once over s from i: a * 43 + 255 is below 2^31 *)
  fun lanes (s : string, i : int, a : int, b : int, c : int, d : int) : int * int * int * int =
    if i = String.size s then (a, b, c, d)
    else
      let val x = Char.ord (String.sub (s, i))
      in lanes (s, i + 1, (a * 31 + x) mod 16777213, (b * 37 + x) mod 16777199, (c * 41 + x) mod 16777183,
                (d * 43 + x) mod 16777153)
      end

  fun digest (a : int, b : int, c : int, d : int) : string =
    let fun hex6 n = StringCvt.padLeft #"0" 6 (Int.fmt StringCvt.HEX n)
    in String.map Char.toLower (hex6 a ^ hex6 b ^ hex6 c ^ hex6 d) end

  fun hash (s : string) : string =
    (if !counting then count (String.size s) else (); digest (lanes (s, 0, 7, 11, 13, 17)))

  (* The same hash of a text given piece by piece, which is never made
     (functors-units, S0): finish gives what hash gives of the pieces fed,
     concatenated *)
  type hasher = {lanes : (int * int * int * int) ref, bytes : int ref}
  fun hasher () : hasher = {lanes = ref (7, 11, 13, 17), bytes = ref 0}
  fun feed ({lanes = l, bytes} : hasher, s : string) : unit =
    let val (a, b, c, d) = !l
    in l := lanes (s, 0, a, b, c, d); bytes := !bytes + String.size s end
  fun finish ({lanes = l, bytes} : hasher) : string =
    (if !counting then count (!bytes) else (); digest (!l))
end
