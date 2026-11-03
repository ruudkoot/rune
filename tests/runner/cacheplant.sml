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
  (* an entry (UnitCache.version 12, UnitStore): RCE, its version, the hash
     of its head and its head, the number of its sections, the hash of each
     and each -- its head its usages, its mark and the units its basis
     names; its sections what else its compile gave, its basis, its code and
     its Mid *)
  fun parse file =
    let val text = binary file
        val () = need (String.isPrefix "RCE" text, "not a cache entry: " ^ file)
        val (version, at) = natural text 3
        val (headSum, at) = stringAt text at
        val (head, at) = stringAt text at
        val (count, at) = natural text at
        val () = need (count <= IntInf.fromInt (size text), "invalid cache section count")
        fun strings (0, at, acc) = (List.rev acc, at)
          | strings (k, at, acc) = let val (x, at) = stringAt text at in strings (k - 1, at, x :: acc) end
        val (sums, at) = strings (IntInf.toInt count, at, [])
        val (sections, at) = strings (IntInf.toInt count, at, [])
        val () = need (at = size text, "a cache entry with more after its sections")
    in {version = version, headSum = headSum, head = head, sums = sums, sections = sections} end
  fun str x = encoded (IntInf.fromInt (size x)) ^ x
  (* written as given, its hashes as they are *)
  fun raw file {version, headSum, head, sums, sections} =
    writeBinary file (String.concat (["RCE", encoded version, str headSum, str head,
                                      encoded (IntInf.fromInt (length sections))]
                                     @ List.map str sums @ List.map str sections))
  fun publish file {version, head, sections, ...} =
    raw file {version = version, headSum = contentHash head, head = head, sums = List.map contentHash sections,
              sections = sections}
  (* a byte of an entry changed, its hashes kept, as a damage leaves it: the
     last of its first usage's value, which names the unit that bound the
     name and then its fingerprint ("head"), so that the head still stands;
     or the last of its source's name in its first section ("file"), which
     still reads; or the last of its Mid ("mid"); false where it has no
     such byte *)
  fun damage file what =
    let val entry as {head, sections, ...} = parse file
        fun flip (text, i) = String.substring (text, 0, i) ^ String.str (if String.sub (text, i) = #"0" then #"1" else #"0")
                             ^ String.extract (text, i + 1, NONE)
    in case (what, sections) of
         ("head", _) =>
           let val (count, at) = natural head 0
           in if count = 0 then false
              else let val (_, at) = stringAt head at
                       val (_, finish) = stringAt head at
                   in raw file {version = #version entry, headSum = #headSum entry, head = flip (head, finish - 1),
                                sums = #sums entry, sections = sections}; true end
           end
       | ("file", meta :: more) =>
           let val (warnings, at) = natural meta 0
               fun skip (0, at) = at | skip (n, at) = skip (n - 1, #2 (stringAt meta at))
               val (name, finish) = stringAt meta (skip (IntInf.toInt warnings, at))
           in if name = "" then false
              else (raw file {version = #version entry, headSum = #headSum entry, head = head, sums = #sums entry,
                              sections = flip (meta, finish - 1) :: more}; true)
           end
       | ("mid", [meta, basis, code, mid]) =>
           if mid = "" then false
           else (raw file {version = #version entry, headSum = #headSum entry, head = head, sums = #sums entry,
                           sections = [meta, basis, code, flip (mid, size mid - 1)]}; true)
       | _ => raise Invalid ("no such part of an entry: " ^ what)
    end
  (* a head's usages, and what follows them *)
  fun usagesOf head =
    let val (count, at) = natural head 0
        val () = need (count <= IntInf.fromInt (size head), "invalid cache usage count")
        fun skip (0, at) = at | skip (n, at) = skip (n - 1, #2 (stringAt head at))
        val finish = skip (IntInf.toInt count * 2, at)
    in (String.substring (head, 0, finish), String.extract (head, finish, NONE)) end
  (* new's usages over all else of old's *)
  fun stale old new =
    let val older = parse old
        val newer = parse new
    in publish new {version = #version older, head = #1 (usagesOf (#head newer)) ^ #2 (usagesOf (#head older)),
                    sections = #sections older} end
  (* where the basis, an entry's second section, is unit's: the offsets of
     its version (after "RBI"), its probe (the hash's, Pickle.probe) and
     what follows the probe; NONE where it is another unit's *)
  fun basisHeader basis unit =
    let val (prefix, found) = Substring.position "RBI" (Substring.full basis)
    in if Substring.isEmpty found then NONE else
       let val at = Substring.size prefix
           val (_, afterVersion) = natural basis (at + 3)
           val (_, afterProbe) = stringAt basis afterVersion
           val (name, _) = stringAt basis afterProbe
       in if name <> unit then NONE else SOME (at + 3, afterVersion, afterProbe) end
    end
  fun rewrite file unit edit =
    let val entry as {sections, ...} = parse file
    in case sections of
         meta :: basis :: more =>
           (case basisHeader basis unit of
              NONE => false
            | SOME offsets => (publish file {version = #version entry, head = #head entry,
                                             sections = meta :: edit (basis, offsets) :: more}; true))
       | _ => false
    end
  fun basisVersion file unit version =
    rewrite file unit (fn (rest, (v, p, _)) => String.substring (rest, 0, v) ^ encoded version ^ String.extract (rest, p, NONE))
  fun basisProbe file unit probe =
    rewrite file unit (fn (rest, (_, p, n)) =>
                         String.substring (rest, 0, p) ^ encoded (IntInf.fromInt (size probe)) ^ probe ^ String.extract (rest, n, NONE))
  (* the schemes an entry keeps of what its code names of other units
     (UnitCache.version 12), at the end of its first section, after its
     warnings, file, others and identity -- by unit, the number and the
     text of each -- each text edited: how many there are *)
  fun schemes file edit =
    let val entry as {sections, ...} = parse file
        val (rest, more) = case sections of rest :: more => (rest, more) | [] => raise Invalid "a cache entry with no sections"
        fun strings (0, at) = at | strings (n, at) = strings (n - 1, #2 (stringAt rest at))
        val (warnings, at) = natural rest 0
        val at = strings (IntInf.toInt warnings + 1, at)
        val (others, at) = natural rest at
        val at = strings (IntInf.toInt others * 2 + 1, at)
        val (count, start) = natural rest at
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
    in publish file {version = #version entry, head = #head entry,
                     sections = (String.substring (rest, 0, at) ^ encoded count ^ tail) :: more}; !found end
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
