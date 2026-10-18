(* Normalisation (UAX #15; docs/plans/utf8.md, M5): NFD and NFC over the
   tables of lib/unicode/normalize_data.sml. NFD decomposes each code
   point fully -- the canonical mappings applied until none applies,
   Hangul syllables by arithmetic -- and then sorts each run of
   non-starters by combining class, stably. NFC composes that again: each
   code point that is not blocked from the last starter (no code point
   between them of the same or a higher class, or none at all) and forms a
   primary composite with it replaces the starter by the composite.

   Over a string, the quick check goes first and its ASCII costs no table.
   Where it does not say Yes, only the segments that need it are
   normalised: a code point of class 0 whose quick check is Yes begins a
   segment that nothing before it reaches across, so the text between two
   such code points is normalised alone and the rest is copied. *)

(* Implements: NORMALIZE *)
structure Normalize :> NORMALIZE =
struct
  structure D = UnicodeNormalizeData

  val version = D.version

  datatype answer = Yes | No | Maybe

  (* the value of the range of v (triples lo, hi, value) that holds c, or 0 *)
  fun lookup (v : int vector) c =
    let
      fun go (lo, hi) =
        if lo >= hi then 0
        else
          let val m = (lo + hi) div 2
          in
            if c < Vector.sub (v, 3 * m) then go (lo, m)
            else if c > Vector.sub (v, 3 * m + 1) then go (m + 1, hi)
            else Vector.sub (v, 3 * m + 2)
          end
    in
      go (0, Vector.length v div 3)
    end

  fun combiningClass c = if c < D.firstCombining then 0 else lookup (D.combiningClass ()) c

  (* 0 Yes, 1 No, 2 Maybe *)
  fun quickCheckOf c = if c < D.firstQuickCheck then 0 else lookup (D.quickCheck ()) c

  (* Hangul (the Unicode Standard, section 3.12) *)
  val sBase = 0xAC00 and lBase = 0x1100 and vBase = 0x1161 and tBase = 0x11A7
  val lCount = 19 and vCount = 21 and tCount = 28
  val nCount = 21 * 28
  val sCount = 19 * 21 * 28

  (* the canonical mapping of c: the index of its triple, or ~1 *)
  fun mapping c =
    let
      val v = D.decomposition ()
      fun go (lo, hi) =
        if lo >= hi then ~1
        else
          let
            val m = (lo + hi) div 2
            val k = Vector.sub (v, 3 * m)
          in
            if c < k then go (lo, m) else if c > k then go (m + 1, hi) else m
          end
    in
      go (0, Vector.length v div 3)
    end

  (* the full canonical decomposition of c, consed onto acc in reverse *)
  fun decompose (c, acc) =
    if c < D.firstDecomposed then c :: acc
    else if c >= sBase andalso c < sBase + sCount then
      let
        val i = c - sBase
        val lv = (lBase + i div nCount) :: acc
        val lv = (vBase + i mod nCount div tCount) :: lv
      in
        if i mod tCount = 0 then lv else (tBase + i mod tCount) :: lv
      end
    else
      case mapping c of
        ~1 => c :: acc
      | m =>
          let
            val v = D.decomposition ()
            val a = Vector.sub (v, 3 * m + 1)
            val b = Vector.sub (v, 3 * m + 2)
          in
            if b = 0 then decompose (a, acc) else decompose (b, decompose (a, acc))
          end

  fun checked c = if Utf8.isScalar c then c else raise Chr

  (* the canonical ordering: each run of non-starters sorted by class,
     stably, by insertion (a run is a few marks) *)
  fun insert (x as (k, _), []) = [x]
    | insert (x as (k, _), (y as (j, _)) :: ys) = if k < j then x :: y :: ys else y :: insert (x, ys)

  fun reorder cs =
    let
      (* the run, in increasing class, consed onto the reversed output *)
      fun flush (run, out) = List.foldl (fn ((_, c), out) => c :: out) out run
      fun go ([], run, out) = rev (flush (run, out))
        | go (c :: cs, run, out) =
            case combiningClass c of
              0 => go (cs, [], c :: flush (run, out))
            | k => go (cs, insert ((k, c), run), out)
    in
      go (cs, [], [])
    end

  fun nfdList cs = reorder (rev (List.foldl (fn (c, acc) => decompose (checked c, acc)) [] cs))

  (* the primary composite of a and b, or ~1 *)
  fun composite (a, b) =
    if b < D.firstSecond then ~1
    else if a >= lBase andalso a < lBase + lCount andalso b >= vBase andalso b < vBase + vCount then
      sBase + ((a - lBase) * vCount + (b - vBase)) * tCount
    else if a >= sBase andalso a < sBase + sCount andalso (a - sBase) mod tCount = 0
            andalso b > tBase andalso b < tBase + tCount then
      a + (b - tBase)
    else
      let
        (* the composites are the decompositions that composition holds
           the index of, in order of first and second *)
        val v = D.composition ()
        val d = D.decomposition ()
        fun go (lo, hi) =
          if lo >= hi then ~1
          else
            let
              val m = (lo + hi) div 2
              val k = 3 * Vector.sub (v, m)
              val x = Vector.sub (d, k + 1)
              val y = Vector.sub (d, k + 2)
            in
              if a < x orelse (a = x andalso b < y) then go (lo, m)
              else if a > x orelse b > y then go (m + 1, hi)
              else Vector.sub (d, k)
            end
      in
        go (0, Vector.length v)
      end

  (* canonical composition of a decomposed, ordered sequence: the starter
     so far (~1 before the first), the code points after it that it has not
     taken (in reverse), the class of the last of them (0 for none), and the
     output so far (in reverse) *)
  fun compose cs =
    let
      fun out (s, between, acc) = between @ (if s = ~1 then acc else s :: acc)
      fun go ([], s, between, _, acc) = rev (out (s, between, acc))
        | go (c :: cs, s, between, last, acc) =
            let
              val k = combiningClass c
              val p = if s <> ~1 andalso (last < k orelse (last = 0 andalso null between))
                      then composite (s, c) else ~1
            in
              if p <> ~1 then go (cs, p, between, last, acc)
              else if k = 0 then go (cs, c, [], 0, out (s, between, acc))
              else go (cs, s, c :: between, k, acc)
            end
    in
      go (cs, ~1, [], 0, [])
    end

  fun nfcList cs = compose (nfdList cs)

  (* the quick check of UAX #15, section 9, over code points from fold *)
  fun quick fold =
    let
      exception Stop
      fun step (c, (last, result)) =
        let
          val k = combiningClass c
        in
          if last > k andalso k <> 0 then raise Stop
          else case quickCheckOf c of
                 0 => (k, result)
               | 1 => raise Stop
               | _ => (k, Maybe)
        end
    in
      (case fold step (0, Yes) of (_, result) => result) handle Stop => No
    end

  fun quickCheckList cs = quick (fn f => fn init => List.foldl (fn (c, a) => f (checked c, a)) init cs)

  fun isNFCList cs =
    case quickCheckList cs of
      Yes => true
    | No => false
    | Maybe => nfcList cs = cs

  (* over a string: the quick check, ASCII without a table, ill-formed
     UTF-8 a No *)
  fun quickCheck s =
    let
      val n = String.size s
      fun go (i, last, result) =
        if i >= n then result
        else
          let val b = Char.ord (String.sub (s, i))
          in
            if b < 0x80 then go (i + 1, 0, result)
            else
              case Utf8.decode (s, i) of
                NONE => No
              | SOME (c, m) =>
                  let val k = combiningClass c
                  in
                    if last > k andalso k <> 0 then No
                    else case quickCheckOf c of
                           0 => go (i + m, k, result)
                         | 1 => No
                         | _ => go (i + m, k, Maybe)
                  end
          end
    in
      go (0, 0, Yes)
    end

  (* the segments of s: a well-formed code point of class 0 whose quick
     check is Yes begins one; the segments that hold anything else
     (another code point, an ill-formed part) are normalised by f over
     their code points, and the text between them is copied *)
  fun bySegment f s =
    let
      val n = String.size s
      fun piece (i, j) = String.substring (s, i, j - i)
      fun fixed (i, j) = Utf8.implode (f (Utf8.explode (piece (i, j))))
      (* the segment from seg to i ends: clean is where the text to copy
         begins, and acc the pieces so far, in reverse *)
      fun close (i, clean, seg, dirty, acc) =
        if dirty then (i, fixed (seg, i) :: piece (clean, seg) :: acc) else (clean, acc)
      fun go (i, clean, seg, dirty, acc) =
        if i >= n then
          let val (clean, acc) = close (n, clean, seg, dirty, acc)
          in String.concat (rev (piece (clean, n) :: acc)) end
        else if Char.ord (String.sub (s, i)) < 0x80 then
          let val (clean, acc) = close (i, clean, seg, dirty, acc)
          in go (i + 1, clean, i, false, acc) end
        else
          case Utf8.decode (s, i) of
            NONE =>
              let val (clean, acc) = close (i, clean, seg, dirty, acc)
              in go (i + #2 (Utf8.next (s, i)), clean, i, true, acc) end
          | SOME (c, m) =>
              if combiningClass c = 0 andalso quickCheckOf c = 0 then
                let val (clean, acc) = close (i, clean, seg, dirty, acc)
                in go (i + m, clean, i, false, acc) end
              else go (i + m, clean, seg, true, acc)
    in
      go (0, 0, 0, false, [])
    end

  fun isAscii s = CharVector.all (fn c => Char.ord c < 0x80) s

  fun nfc s = case quickCheck s of Yes => s | _ => bySegment nfcList s

  fun isNFC s =
    case quickCheck s of
      Yes => true
    | No => false
    | Maybe => bySegment nfcList s = s

  fun nfd s = if isAscii s then s else Utf8.implode (nfdList (Utf8.explode s))
end
