(* SplitMix64 (docs/plans/quickcheck.md, D2): the generator of Vigna's
   splitmix64.c, and the split of Java's SplittableRandom, whose mixGamma is
   taken from the JDK (the paper's printed version tests the wrong way round).
   All the arithmetic is in Word64, so that the numbers are the same on every
   compiler; an int appears only at the interface. *)

(* Implements: RANDOM *)
structure Random :> RANDOM =
struct
  type gen = {seed : Word64.word, gamma : Word64.word}

  (* the golden gamma: 2^64 / the golden ratio, made odd *)
  val golden : Word64.word = 0wx9E3779B97F4A7C15

  (* the finaliser: Stafford's variant 13, as splitmix64.c has it *)
  fun hash (z : Word64.word) : Word64.word =
    let
      val z = Word64.* (Word64.xorb (z, Word64.>> (z, 0w30)), 0wxBF58476D1CE4E5B9)
      val z = Word64.* (Word64.xorb (z, Word64.>> (z, 0w27)), 0wx94D049BB133111EB)
    in
      Word64.xorb (z, Word64.>> (z, 0w31))
    end

  fun bitCount (w : Word64.word) : int =
    let fun go (w, n) = if w = 0w0 then n else go (Word64.andb (w, Word64.- (w, 0w1)), n + 1)
    in go (w, 0) end

  (* the gamma of a new generator: odd, with at least 24 changes between
     neighbouring bits (SplittableRandom.mixGamma) *)
  fun mixGamma (z : Word64.word) : Word64.word =
    let
      val z = Word64.* (Word64.xorb (z, Word64.>> (z, 0w33)), 0wxFF51AFD7ED558CCD)
      val z = Word64.* (Word64.xorb (z, Word64.>> (z, 0w33)), 0wxC4CEB9FE1A85EC53)
      val z = Word64.orb (Word64.xorb (z, Word64.>> (z, 0w33)), 0w1)
    in
      if bitCount (Word64.xorb (z, Word64.>> (z, 0w1))) < 24 then Word64.xorb (z, 0wxAAAAAAAAAAAAAAAA) else z
    end

  fun fromSeed (s : Word64.word) : gen = {seed = s, gamma = golden}

  fun word64 ({seed, gamma} : gen) : Word64.word * gen =
    let val s = Word64.+ (seed, gamma)
    in (hash s, {seed = s, gamma = gamma}) end

  (* new SplittableRandom (nextLong (), mixGamma (nextSeed ())) *)
  fun split (g : gen) : gen * gen =
    let
      val (x, {seed, gamma}) = word64 g
      val s = Word64.+ (seed, gamma)
    in
      ({seed = s, gamma = gamma}, {seed = x, gamma = mixGamma s})
    end

  (* the high and the low word of the 128-bit product, from 32-bit halves *)
  fun multiply (a : Word64.word, b : Word64.word) : Word64.word * Word64.word =
    let
      val mask = 0wxFFFFFFFF : Word64.word
      val (ah, al) = (Word64.>> (a, 0w32), Word64.andb (a, mask))
      val (bh, bl) = (Word64.>> (b, 0w32), Word64.andb (b, mask))
      val ll = Word64.* (al, bl)
      val lh = Word64.* (al, bh)
      val hl = Word64.* (ah, bl)
      val hh = Word64.* (ah, bh)
      val cross = Word64.+ (Word64.+ (Word64.>> (ll, 0w32), Word64.andb (lh, mask)), hl)
    in
      (Word64.+ (Word64.+ (hh, Word64.>> (lh, 0w32)), Word64.>> (cross, 0w32)),
       Word64.orb (Word64.<< (cross, 0w32), Word64.andb (ll, mask)))
    end

  (* Lemire, "Fast random integer generation in an interval" (2019): the
     high word of x * n, drawn again while the low word is below
     (2^64 - n) mod n, which is computed only when the low word is below n *)
  fun below (n : Word64.word) (g : gen) : Word64.word * gen =
    if n = 0w0 then raise Domain
    else
      let
        fun draw g = let val (x, g) = word64 g val (hi, lo) = multiply (x, n) in (hi, lo, g) end
        val (hi, lo, g) = draw g
      in
        if lo >= n then (hi, g)
        else
          let
            val t = Word64.mod (Word64.~ n, n)
            fun again (hi, lo, g) = if lo >= t then (hi, g) else again (draw g)
          in
            again (hi, lo, g)
          end
      end

  fun int (lo : int, hi : int) (g : gen) : int * gen =
    if hi < lo then raise Domain
    else
      let
        val span = Word64.+ (Word64.- (Word64.fromInt hi, Word64.fromInt lo), 0w1)
        val (x, g) = if span = 0w0 then word64 g else below span g
      in
        (Word64.toIntX (Word64.+ (Word64.fromInt lo, x)), g)
      end

  (* 53 bits, as 27 and 26 so that an int of 31 bits holds each *)
  fun real (g : gen) : real * gen =
    let
      val (x, g) = word64 g
      val high = Word64.toInt (Word64.>> (x, 0w37))
      val low = Word64.toInt (Word64.andb (Word64.>> (x, 0w11), 0wx3FFFFFF))
    in
      ((Real.fromInt high * 67108864.0 + Real.fromInt low) / 9007199254740992.0, g)
    end

  fun bool (g : gen) : bool * gen =
    let val (x, g) = word64 g
    in (Word64.>> (x, 0w63) = 0w1, g) end

  fun hashString (s : string) : Word64.word =
    hash (CharVector.foldl (fn (c, h) => hash (Word64.+ (Word64.xorb (h, Word64.fromInt (Char.ord c)), golden)))
                           (Word64.fromInt (String.size s)) s)

  fun hex (w : Word64.word) : string = StringCvt.padLeft #"0" 16 (Word64.fmt StringCvt.HEX w)

  fun toString ({seed, gamma} : gen) : string = hex seed ^ ":" ^ hex gamma

  fun fromString (s : string) : gen option =
    case String.fields (fn c => c = #":") s of
      [a, b] =>
        (case (StringCvt.scanString (Word64.scan StringCvt.HEX) a, StringCvt.scanString (Word64.scan StringCvt.HEX) b) of
           (SOME seed, SOME gamma) =>
             if Word64.andb (gamma, 0w1) = 0w1 then SOME {seed = seed, gamma = gamma} else NONE
         | _ => NONE)
    | _ => NONE

  (* 16 bytes of /dev/urandom as a seed and a gamma; the clock when there is
     no such file *)
  fun fromEntropy () : gen =
    let
      fun word (v, i) =
        Word8Vector.foldl (fn (b, w) => Word64.orb (Word64.<< (w, 0w8), Word64.fromLarge (Word8.toLarge b))) 0w0
                          (Word8VectorSlice.vector (Word8VectorSlice.slice (v, i, SOME 8)))
      val bytes =
        (let
           val ins = BinIO.openIn "/dev/urandom"
         in
           BinIO.inputN (ins, 16) before BinIO.closeIn ins
         end)
        handle IO.Io _ => Word8Vector.fromList []
    in
      if Word8Vector.length bytes = 16 then {seed = word (bytes, 0), gamma = mixGamma (word (bytes, 8))}
      else
        let val t = Word64.fromLargeInt (Time.toMicroseconds (Time.now ()))
        in {seed = hash t, gamma = mixGamma (hash (Word64.+ (t, golden)))} end
    end
end
