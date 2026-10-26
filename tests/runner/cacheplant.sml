(* Independent cache corruption writer for incremental S55/S67. Deliberately
   does not use UnitCache/Pickle's production reader or writer. *)
structure CachePlant =
struct
  open Sh
  exception Invalid of string
  fun need (ok, why) = if ok then () else raise Invalid why
  fun natural text at =
    let fun loop (at, scale, value, count) =
          (need (at < size text andalso count < 20, "truncated/oversized cache natural");
           let val byte = Char.ord (String.sub (text, at))
               val value = value + IntInf.fromInt (byte mod 128) * scale
           in if byte < 128 then (value, at + 1) else loop (at + 1, scale * 128, value, count + 1) end)
    in loop (at, 1, 0, 0) end
  fun encoded n =
    (need (n >= 0, "negative cache natural");
     if n < 128 then str (Char.chr (IntInf.toInt n))
     else str (Char.chr (128 + IntInf.toInt (IntInf.mod (n, 128)))) ^ encoded (IntInf.div (n, 128)))
  fun stringAt text at =
    let val (length, at) = natural text at
        val () = need (length <= IntInf.fromInt (size text - at), "truncated cache string")
        val length = IntInf.toInt length
    in (String.substring (text, at, length), at + length) end
  (* the compiler's hash (Pickle.hash, rx2fw: docs/plans/functors-units.md,
     D11), written again here in Word64 a byte at a time: two lanes of 63
     bits from xxHash64's primes with bit 63 cleared, seven bytes a step,
     the tail and the length a step each, xxHash64's ending *)
  fun contentHash text =
    let fun w (h, m, l) = Word64.orb (Word64.orb (Word64.<< (Word64.fromInt h, 0w42), Word64.<< (Word64.fromInt m, 0w21)),
                                      Word64.fromInt l)
        val p1 = w (0x78dde, 0xd8c2f, 0xbca87)  val p2 = w (0x10acab, 0x11e93e, 0x14eb4f)
        val p3 = w (0x59599, 0x1d8cf1, 0x1779f9)  val p4 = w (0x17af2, 0x13be15, 0x12ae63)
        val mask = w (0x1fffff, 0x1fffff, 0x1fffff)
        fun rotl (x, r) = Word64.andb (Word64.orb (Word64.<< (x, r), Word64.>> (x, 0w63 - r)), mask)
        fun step ((a, b), x) =
          (Word64.andb (Word64.* (rotl (Word64.andb (Word64.+ (a, Word64.* (x, p2)), mask), 0w31), p1), mask),
           Word64.andb (Word64.* (rotl (Word64.andb (Word64.+ (b, Word64.* (x, p4)), mask), 0w27), p3), mask))
        fun byte i = Word64.fromInt (Char.ord (String.sub (text, i)))
        fun group (i, k) = if k = 0 then 0w0 else Word64.orb (byte i, Word64.<< (group (i + 1, k - 1), 0w8))
        fun go (i, lanes) =
          if i + 7 <= size text then go (i + 7, step (lanes, group (i, 7)))
          else if i < size text then step (lanes, group (i, size text - i)) else lanes
        val (a, b) = step (go (0, (p1, p3)), Word64.fromInt (size text))
        fun ending h =
          let val h = Word64.andb (Word64.* (Word64.xorb (h, Word64.>> (h, 0w33)), p2), mask)
              val h = Word64.andb (Word64.* (Word64.xorb (h, Word64.>> (h, 0w29)), p3), mask)
          in Word64.xorb (h, Word64.>> (h, 0w32)) end
        fun hex h = String.implode (List.tabulate (16, fn i =>
                      String.sub ("0123456789abcdef", Word64.toInt (Word64.andb (Word64.>> (h, Word.fromInt (60 - 4 * i)), 0wxF)))))
    in hex (ending a) ^ hex (ending b) end
  fun binary file = let val input = BinIO.openIn file
                    in Byte.bytesToString (BinIO.inputAll input) before BinIO.closeIn input end
  fun writeBinary file text = let val output = BinIO.openOut file
                             in BinIO.output (output, Byte.stringToBytes text); BinIO.closeOut output end
  fun parse file =
    let val text = binary file
        val () = need (String.isPrefix "RCE" text, "not a cache entry: " ^ file)
        val (version, at) = natural text 3
        val (_, at) = stringAt text at
        val body = String.extract (text, at, NONE)
        val (count, at) = natural body 0
        val () = need (count <= IntInf.fromInt (size body), "invalid cache usage count")
        fun skip (0, at) = at | skip (n, at) = skip (n - 1, #2 (stringAt body at))
        val finish = skip (IntInf.toInt count * 2, at)
    in (version, String.substring (body, 0, finish), String.extract (body, finish, NONE)) end
  fun publish file version body =
    let val hash = contentHash body
    in writeBinary file ("RCE" ^ encoded version ^ encoded (IntInf.fromInt (size hash)) ^ hash ^ body) end
  fun stale old new =
    let val (version, _, rest) = parse old
        val (_, usages, _) = parse new
    in publish new version (usages ^ rest) end
  (* where the basis in an entry's rest is unit's: the offsets of its
     version (after "RBI"), its probe (the hash's, Pickle.probe) and what
     follows the probe; NONE where it is another unit's *)
  fun basisHeader rest unit =
    let val (prefix, found) = Substring.position "RBI" (Substring.full rest)
    in if Substring.isEmpty found then NONE else
       let val at = Substring.size prefix
           val (_, afterVersion) = natural rest (at + 3)
           val (_, afterProbe) = stringAt rest afterVersion
           val (name, _) = stringAt rest afterProbe
       in if name <> unit then NONE else SOME (at + 3, afterVersion, afterProbe) end
    end
  fun rewrite file unit edit =
    let val (outer, usages, rest) = parse file
    in case basisHeader rest unit of
         NONE => false
       | SOME offsets => (publish file outer (usages ^ edit (rest, offsets)); true)
    end
  fun basisVersion file unit version =
    rewrite file unit (fn (rest, (v, p, _)) => String.substring (rest, 0, v) ^ encoded version ^ String.extract (rest, p, NONE))
  fun basisProbe file unit probe =
    rewrite file unit (fn (rest, (_, p, n)) =>
                         String.substring (rest, 0, p) ^ encoded (IntInf.fromInt (size probe)) ^ probe ^ String.extract (rest, n, NONE))
  (* the schemes an entry keeps of what its code names of other units
     (UnitCache.version 10), after its warnings, file, others, basis,
     identity, code, Mid and mark -- by unit, the number and the text of
     each -- each text edited: how many there are *)
  fun schemes file edit =
    let val (outer, usages, rest) = parse file
        fun strings (0, at) = at | strings (n, at) = strings (n - 1, #2 (stringAt rest at))
        val (warnings, at) = natural rest 0
        val at = strings (IntInf.toInt warnings + 1, at)
        val (others, at) = natural rest at
        val at = strings (IntInf.toInt others * 2 + 4, at)
        val (_, at) = natural rest at
        val (count, start) = natural rest at
        fun str x = encoded (IntInf.fromInt (size x)) ^ x
        val found = ref 0
        fun texts (0, at) = ("", at)
          | texts (k, at) = let val (n, at) = natural rest at
                                val (t, at) = stringAt rest at
                                val (more, at) = texts (k - 1, at)
                            in found := !found + 1; (encoded n ^ str (edit (n, t)) ^ more, at) end
        fun units (0, at) = ("", at)
          | units (k, at) = let val (u, at) = stringAt rest at
                                val (n, at) = natural rest at
                                val (ts, at) = texts (IntInf.toInt n, at)
                                val (more, at) = units (k - 1, at)
                            in (str u ^ encoded n ^ ts ^ more, at) end
        val (tail, finish) = units (IntInf.toInt count, start)
        val () = need (finish = size rest, "a cache entry with more after its schemes")
    in publish file outer (usages ^ String.substring (rest, 0, at) ^ encoded count ^ tail); !found end
  fun command [old, new] = stale old new
    | command ("--basis-version" :: version :: unit :: files) =
        let val version = case IntInf.fromString version of SOME n => n | NONE => raise Invalid "invalid basis version"
            val changed = List.map (fn file => basisVersion file unit version) files
        in need (List.exists (fn value => value) changed, "no cache entry of " ^ unit) end
    | command ("--basis-probe" :: probe :: unit :: files) =
        need (List.exists (fn value => value) (List.map (fn file => basisProbe file unit probe) files),
              "no cache entry of " ^ unit)
    | command _ = raise Invalid "usage: rune-cache-plant OLD NEW | --basis-version N UNIT ENTRY... | --basis-probe P UNIT ENTRY..."
end
