(* Bytes for what the compiler keeps between compiles (the incremental
   roadmap's M6): a writer that gathers them and a reader that takes them
   apart, of numbers, strings, lists and options; and the hash that names a
   content. A number is a varint, a natural one as itself and any other
   zigzagged, so that it costs a byte below 128 or 64; every number written
   is far below 2^29, which every host's int holds doubled. *)
structure Pickle =
struct
  exception Bad of string
  (* bytes to write past the host's longest array (room) *)
  exception TooLong of int

  (* ---- writing: bytes gathered in place, in an array that doubles when
     it is full (it was a list of chunks, newest first, a string a byte:
     functors-units, M4) ---- *)

  type writer = {bytes : CharArray.array ref, used : int ref}

  fun writer () : writer = {bytes = ref (CharArray.array (64, #"\000")), used = ref 0}
  (* doubling, but no further than the host's longest array: on Rune
     CharArray.maxLen is 100,000,000, which a unit's Mid of a million copied
     nodes and a big environment reaches (functors-units M8: funnest at depth
     14 in --units --whole, where 2 * 67,108,864 raised Size) *)
  fun room ({bytes, used} : writer, n : int) : unit =
    if !used + n <= CharArray.length (!bytes) then ()
    else if !used + n > CharArray.maxLen then raise TooLong (!used + n)
    else
      let val bigger = CharArray.array (Int.min (CharArray.maxLen, Int.max (2 * CharArray.length (!bytes), !used + n)), #"\000")
      in CharArray.copy {src = !bytes, dst = bigger, di = 0}; bytes := bigger end
  (* the whole array, then its part written: two copies of the bytes,
     where a slice's vector makes a long string a byte at a time on Rune *)
  fun contents ({bytes, used} : writer) : string = String.substring (CharArray.vector (!bytes), 0, !used)
  fun bytes (w as {bytes = b, used} : writer, s : string) : unit =
    (room (w, String.size s); CharArray.copyVec {src = s, dst = !b, di = !used}; used := !used + String.size s)

  fun byte (w as {bytes = b, used} : writer, n : int) : unit =
    (room (w, 1); CharArray.update (!b, !used, Char.chr n); used := !used + 1)

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

  (* ---- the hash of a content: rx2fw (docs/plans/functors-units.md, D11),
     two lanes of 63 bits, every operation mod 2^63, 126 bits in 32
     hexadecimal digits. The lanes take a text seven bytes a step, each
     seven a little-endian number x:

       A (a, x) = rotl (a + x * P2, 31) * P1
       B (b, x) = rotl (b + x * P4, 27) * P3

     from a = P1 and b = P3, rotl a rotation of 63 bits; the last one to six
     bytes are a step of their own, and the text's length a step after
     them. Each lane ends as xxHash64's does (h ^= h >> 33; h *= P2;
     h ^= h >> 29; h *= P3; h ^= h >> 32), and P1 to P4 are xxHash64's
     primes with bit 63 cleared, the same numbers mod 2^63. Hashes are
     combined as texts: a fingerprint of fingerprints is the hash of their
     digits.

     The steps follow the width of the host's Word: where it is 63 bits
     (Rune), as written; where it is wider, each sum masked to 63 bits
     before its rotation and each lane before a shift of its ending; where
     it is narrower, the same in Word64. A host whose arithmetic still gives
     other values (SML/NJ's 32-bit Word64) gives another probe, which keeps
     its caches apart from everyone else's (UnitCache, UnitBasis) ---- *)

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
    if !counting then
      let
        val l = !label
        fun add [] = [(l, n, 1)]
          | add ((k, b, c) :: rest) = if k = l then (k, b + n, c + 1) :: rest else (k, b, c) :: add rest
      in counted := add (!counted) end
    else ()

  val width = Word.wordSize

  (* a constant of 63 bits from three pieces of 21: SML/NJ 110.99.9 crashes
     on some uses of a word constant of 2^30 or more
     (docs/bugreport/smlnj/MLRISC/movabsq-spilled) *)
  fun w63 (h : int, m : int, l : int) : word =
    Word.orb (Word.orb (Word.<< (Word.fromInt h, 0w42), Word.<< (Word.fromInt m, 0w21)), Word.fromInt l)
  fun l63 (h : int, m : int, l : int) : Word64.word =
    Word64.orb (Word64.orb (Word64.<< (Word64.fromInt h, 0w42), Word64.<< (Word64.fromInt m, 0w21)), Word64.fromInt l)
  val p1 = w63 (0x78dde, 0xd8c2f, 0xbca87)        (* 0x1E3779B185EBCA87 *)
  val p2 = w63 (0x10acab, 0x11e93e, 0x14eb4f)     (* 0x42B2AE3D27D4EB4F *)
  val p3 = w63 (0x59599, 0x1d8cf1, 0x1779f9)      (* 0x165667B19E3779F9 *)
  val p4 = w63 (0x17af2, 0x13be15, 0x12ae63)      (* 0x05EBCA77C2B2AE63 *)
  val m63 = w63 (0x1fffff, 0x1fffff, 0x1fffff)
  val l1 = l63 (0x78dde, 0xd8c2f, 0xbca87)
  val l2 = l63 (0x10acab, 0x11e93e, 0x14eb4f)
  val l3 = l63 (0x59599, 0x1d8cf1, 0x1779f9)
  val l4 = l63 (0x17af2, 0x13be15, 0x12ae63)
  val lm = l63 (0x1fffff, 0x1fffff, 0x1fffff)

  (* the 16 hexadecimal digits of a lane, a nibble at a time *)
  fun hexOf (nibble : int -> int) : string =
    CharVector.tabulate (16, fn i => String.sub ("0123456789abcdef", nibble (60 - 4 * i)))
  fun hexWord (w : word) : string = hexOf (fn s => Word.toInt (Word.andb (Word.>> (w, Word.fromInt s), 0wxF)))
  fun hexLong (w : Word64.word) : string = hexOf (fn s => Word64.toInt (Word64.andb (Word64.>> (w, Word.fromInt s), 0wxF)))

  (* A text fed to the lanes a and b, with k bytes pending in p (fewer than
     seven, little-endian): the lanes, the bytes then pending and how many.
     steps63 where Word is 63 bits; stepsWide where it is wider *)
  fun steps63 (s : string, a : word, b : word, p : word, k : int) : word * word * word * int =
    let
      val q1 = p1  val q2 = p2  val q3 = p3  val q4 = p4
      val len = String.size s
      fun byte i = Word.fromInt (Char.ord (String.sub (s, i)))
      fun fill (i, w, j) = if j = 7 orelse i = len then (i, w, j) else fill (i + 1, Word.orb (w, Word.<< (byte i, Word.fromInt (8 * j))), j + 1)
      val (i, w, j) = fill (0, p, k)
      fun step (a, b, x) =
        let val a = a + x * q2
            val b = b + x * q4
        in (Word.orb (Word.<< (a, 0w31), Word.>> (a, 0w32)) * q1, Word.orb (Word.<< (b, 0w27), Word.>> (b, 0w36)) * q3) end
      fun go (i, a, b) =
        if i + 7 > len then (i, a, b)
        else
          let
            val x = (((((byte (i + 6) * 0w256 + byte (i + 5)) * 0w256 + byte (i + 4)) * 0w256 + byte (i + 3)) * 0w256
                     + byte (i + 2)) * 0w256 + byte (i + 1)) * 0w256 + byte i
            val a = a + x * q2
            val b = b + x * q4
          in go (i + 7, Word.orb (Word.<< (a, 0w31), Word.>> (a, 0w32)) * q1, Word.orb (Word.<< (b, 0w27), Word.>> (b, 0w36)) * q3) end
      fun tl (i, m, acc) = if m < i then acc else tl (i, m - 1, acc * 0w256 + byte m)
    in
      if j < 7 then (a, b, w, j)
      else
        let
          val (a, b) = step (a, b, w)
          val (i, a, b) = go (i, a, b)
        in (a, b, tl (i, len - 1, 0w0), len - i) end
    end

  fun stepsWide (s : string, a : word, b : word, p : word, k : int) : word * word * word * int =
    let
      val q1 = p1  val q2 = p2  val q3 = p3  val q4 = p4  val m = m63
      val len = String.size s
      fun byte i = Word.fromInt (Char.ord (String.sub (s, i)))
      fun fill (i, w, j) = if j = 7 orelse i = len then (i, w, j) else fill (i + 1, Word.orb (w, Word.<< (byte i, Word.fromInt (8 * j))), j + 1)
      val (i, w, j) = fill (0, p, k)
      fun step (a, b, x) =
        let val a = Word.andb (a + x * q2, m)
            val b = Word.andb (b + x * q4, m)
        in (Word.orb (Word.<< (a, 0w31), Word.>> (a, 0w32)) * q1, Word.orb (Word.<< (b, 0w27), Word.>> (b, 0w36)) * q3) end
      fun go (i, a, b) =
        if i + 7 > len then (i, a, b)
        else
          let
            val x = (((((byte (i + 6) * 0w256 + byte (i + 5)) * 0w256 + byte (i + 4)) * 0w256 + byte (i + 3)) * 0w256
                     + byte (i + 2)) * 0w256 + byte (i + 1)) * 0w256 + byte i
            val (a, b) = step (a, b, x)
          in go (i + 7, a, b) end
      fun tl (i, m, acc) = if m < i then acc else tl (i, m - 1, acc * 0w256 + byte m)
    in
      if j < 7 then (a, b, w, j)
      else
        let
          val (a, b) = step (a, b, w)
          val (i, a, b) = go (i, a, b)
        in (a, b, tl (i, len - 1, 0w0), len - i) end
    end

  (* the same in Word64 where Word is narrower, a byte at a time *)
  fun stepLong (a : Word64.word, b : Word64.word, x : Word64.word) : Word64.word * Word64.word =
    let
      val a = Word64.andb (Word64.+ (a, Word64.* (x, l2)), lm)
      val b = Word64.andb (Word64.+ (b, Word64.* (x, l4)), lm)
    in (Word64.* (Word64.orb (Word64.<< (a, 0w31), Word64.>> (a, 0w32)), l1),
        Word64.* (Word64.orb (Word64.<< (b, 0w27), Word64.>> (b, 0w36)), l3)) end
  fun stepsNarrow (s : string, a : Word64.word, b : Word64.word, p : Word64.word, k : int)
      : Word64.word * Word64.word * Word64.word * int =
    let
      val len = String.size s
      fun go (i, a, b, p, k) =
        if i = len then (a, b, p, k)
        else
          let val p = Word64.orb (p, Word64.<< (Word64.fromInt (Char.ord (String.sub (s, i))), Word.fromInt (8 * k)))
          in if k = 6 then let val (a, b) = stepLong (a, b, p) in go (i + 1, a, b, 0w0, 0) end
             else go (i + 1, a, b, p, k + 1)
          end
    in go (0, a, b, p, k) end

  (* the digest of lanes a and b after a text of n bytes, k of them pending
     in p: the pending ones a step, the length a step, and each lane ended *)
  fun digest63 (a : word, b : word, p : word, k : int, n : int) : string =
    let
      val q1 = p1  val q2 = p2  val q3 = p3  val q4 = p4
      fun step (a, b, x) =
        let val a = a + x * q2
            val b = b + x * q4
        in (Word.orb (Word.<< (a, 0w31), Word.>> (a, 0w32)) * q1, Word.orb (Word.<< (b, 0w27), Word.>> (b, 0w36)) * q3) end
      val (a, b) = if k > 0 then step (a, b, p) else (a, b)
      val (a, b) = step (a, b, Word.fromInt n)
      fun ending h =
        let
          val h = Word.xorb (h, Word.>> (h, 0w33)) * q2
          val h = Word.xorb (h, Word.>> (h, 0w29)) * q3
        in Word.xorb (h, Word.>> (h, 0w32)) end
    in hexWord (ending a) ^ hexWord (ending b) end

  fun digestWide (a : word, b : word, p : word, k : int, n : int) : string =
    let
      val q1 = p1  val q2 = p2  val q3 = p3  val q4 = p4  val m = m63
      fun step (a, b, x) =
        let val a = Word.andb (a + x * q2, m)
            val b = Word.andb (b + x * q4, m)
        in (Word.orb (Word.<< (a, 0w31), Word.>> (a, 0w32)) * q1, Word.orb (Word.<< (b, 0w27), Word.>> (b, 0w36)) * q3) end
      val (a, b) = if k > 0 then step (a, b, p) else (a, b)
      val (a, b) = step (a, b, Word.fromInt n)
      fun ending h =
        let
          val h = Word.andb (h, m)
          val h = Word.andb (Word.xorb (h, Word.>> (h, 0w33)) * q2, m)
          val h = Word.andb (Word.xorb (h, Word.>> (h, 0w29)) * q3, m)
        in Word.xorb (h, Word.>> (h, 0w32)) end
    in hexWord (ending a) ^ hexWord (ending b) end

  fun digestNarrow (a : Word64.word, b : Word64.word, p : Word64.word, k : int, n : int) : string =
    let
      val (a, b) = if k > 0 then stepLong (a, b, p) else (a, b)
      val (a, b) = stepLong (a, b, Word64.fromInt n)
      fun ending h =
        let
          val h = Word64.andb (h, lm)
          val h = Word64.andb (Word64.* (Word64.xorb (h, Word64.>> (h, 0w33)), l2), lm)
          val h = Word64.andb (Word64.* (Word64.xorb (h, Word64.>> (h, 0w29)), l3), lm)
        in Word64.xorb (h, Word64.>> (h, 0w32)) end
    in hexLong (ending a) ^ hexLong (ending b) end

  fun hash (s : string) : string =
    (count (String.size s);
     if width = 63 then let val (a, b, p, k) = steps63 (s, p1, p3, 0w0, 0) in digest63 (a, b, p, k, String.size s) end
     else if width > 63 then let val (a, b, p, k) = stepsWide (s, p1, p3, 0w0, 0) in digestWide (a, b, p, k, String.size s) end
     else let val (a, b, p, k) = stepsNarrow (s, l1, l3, 0w0, 0) in digestNarrow (a, b, p, k, String.size s) end)

  (* The same hash of a text given piece by piece, which is never made:
     finish gives what hash gives of the pieces fed, concatenated *)
  datatype lanes = Wide of word * word * word | Narrow of Word64.word * Word64.word * Word64.word
  type hasher = {lanes : lanes ref, pending : int ref, bytes : int ref}
  fun hasher () : hasher =
    {lanes = ref (if width >= 63 then Wide (p1, p3, 0w0) else Narrow (l1, l3, 0w0)), pending = ref 0, bytes = ref 0}
  fun feed ({lanes, pending, bytes} : hasher, s : string) : unit =
    (bytes := !bytes + String.size s;
     case !lanes of
       Wide (a, b, p) =>
         let val (a, b, p, k) = if width = 63 then steps63 (s, a, b, p, !pending) else stepsWide (s, a, b, p, !pending)
         in lanes := Wide (a, b, p); pending := k end
     | Narrow (a, b, p) =>
         let val (a, b, p, k) = stepsNarrow (s, a, b, p, !pending)
         in lanes := Narrow (a, b, p); pending := k end)
  fun finish ({lanes, pending, bytes} : hasher) : string =
    (count (!bytes);
     case !lanes of
       Wide (a, b, p) => if width = 63 then digest63 (a, b, p, !pending, !bytes) else digestWide (a, b, p, !pending, !bytes)
     | Narrow (a, b, p) => digestNarrow (a, b, p, !pending, !bytes))

  (* The probe: the digest of a text made to show any difference in how a
     host works the hash out -- pieces of 0 to 15 bytes fed one after
     another, so that every count of bytes pending meets every tail; a long
     text; the bytes 128 to 255; and seven bytes 255, the largest number a
     step takes (a lane passes 2^62 at its first step, so a Word of 64 bits
     without the masks, or of 31 or 32, gives another). Worked out once,
     when first asked (UnitCache.configuration, a basis's header), and not
     counted with what a compile hashes *)
  val probed : string option ref = ref NONE
  val () = CompilerState.cellRoot ("Pickle.probed", probed)
  fun probe () : string =
    case !probed of
      SOME d => d
    | NONE =>
        let
          val was = !counting
          val () = counting := false
          val h = hasher ()
          fun piece (k, f) = feed (h, CharVector.tabulate (k, f))
          val () = List.app (fn k => piece (k, fn i => Char.chr ((k * 37 + i * 101) mod 256))) (List.tabulate (16, fn k => k))
          val () = piece (1000, fn i => Char.chr ((i * 7 + i div 13) mod 256))
          val () = piece (128, fn i => Char.chr (128 + i))
          val () = piece (7, fn _ => Char.chr 255)
          val d = finish h
        in counting := was; probed := SOME d; d end
end
