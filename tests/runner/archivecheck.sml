(* Independent readers for distribution metadata. Native gzip/unzip only
   decode compression; member sets, bounds and assertions remain SML. *)
structure ArchiveCheck =
struct
  open Sh
  exception Invalid of string
  fun need (ok, why) = if ok then () else raise Invalid why
  fun binary file = let val input = BinIO.openIn file
                    in Byte.bytesToString (BinIO.inputAll input) before BinIO.closeIn input end
  fun slice text at width =
    (need (at >= 0 andalso width >= 0 andalso at <= size text andalso width <= size text - at, "truncated archive");
     String.substring (text, at, width))
  fun unsigned text at width =
    let val bytes = slice text at width
    in CharVector.foldr (fn (c, value) => value * 256 + IntInf.fromInt (Char.ord c)) 0 bytes end
  fun small text at width =
    let val value = unsigned text at width
    in need (value <= IntInf.fromInt (size text), "archive offset/length is out of bounds"); IntInf.toInt value end
  fun zero text = CharVector.all (fn c => c = #"\000") text
  fun clean text = Substring.string (Substring.takel (fn c => c <> #"\000") (Substring.full text))
  fun octal text =
    let val text = Hosts.trim (clean text)
    in case IntInf.scan StringCvt.OCT Substring.getc (Substring.full text) of
         SOME (n, rest) => (need (Substring.isEmpty rest andalso n >= 0, "invalid tar number"); n)
       | NONE => if text = "" then 0 else raise Invalid "invalid tar number" end
  type member = {name : string, mode : IntInf.int, uid : IntInf.int, gid : IntInf.int, mtime : IntInf.int, data : string}
  fun tar text =
    let fun loop (at, found) =
          let val header = slice text at 512
          in if zero header then (need (zero (slice text (at + 512) 512), "tar has no complete end marker"); List.rev found) else
             let val expected = octal (slice header 148 8)
                 val checksum = CharVector.foldli (fn (i, c, total) => total + (if i >= 148 andalso i < 156 then 32 else Char.ord c)) 0 header
                 val () = need (expected = IntInf.fromInt checksum, "invalid tar header checksum")
                 val kind = String.sub (header, 156)
                 val () = need (kind = #"0" orelse kind = #"\000", "distribution tar contains a non-file member")
                 val name = clean (slice header 0 100)
                 val prefix = clean (slice header 345 155)
                 val name = if prefix = "" then name else prefix ^ "/" ^ name
                 val length = octal (slice header 124 12)
                 val () = need (length <= IntInf.fromInt (size text), "tar member length is out of bounds")
                 val length = IntInf.toInt length
                 val data = slice text (at + 512) length
                 val member = {name = name, mode = octal (slice header 100 8), uid = octal (slice header 108 8),
                               gid = octal (slice header 116 8), mtime = octal (slice header 136 12), data = data} : member
                 val next = at + 512 + ((length + 511) div 512) * 512
             in loop (next, member :: found) end
          end
    in loop (0, []) end
  type zipped = {name : string, method : IntInf.int, size : IntInf.int, attributes : IntInf.int}
  fun zip text =
    let fun ending at =
          if at < 0 then raise Invalid "zip end record is missing"
          else if slice text at 4 = "PK\005\006" then at else ending (at - 1)
        val () = need (size text >= 22, "truncated zip")
        val ending = ending (size text - 22)
        val () = need (unsigned text (ending + 4) 2 = 0 andalso unsigned text (ending + 6) 2 = 0, "split zip is unsupported")
        val count = small text (ending + 10) 2
        val () = need (unsigned text (ending + 8) 2 = IntInf.fromInt count, "inconsistent zip member count")
        val start = small text (ending + 16) 4
        val directorySize = small text (ending + 12) 4
        val () = need (start <= ending andalso directorySize = ending - start, "invalid zip central directory")
        fun loop (0, at, found) = (need (at = ending, "zip directory has extra or missing entries"); List.rev found)
          | loop (n, at, found) =
            let val () = need (slice text at 4 = "PK\001\002", "invalid zip directory entry")
                val length = small text (at + 28) 2
                val extra = small text (at + 30) 2
                val comment = small text (at + 32) 2
                val name = slice text (at + 46) length
                val () = need (name <> "" andalso not (String.isSuffix "/" name), "distribution zip contains a directory member")
                val localOffset = small text (at + 42) 4
                val () = need (slice text localOffset 4 = "PK\003\004", "invalid zip local header")
                val localName = small text (localOffset + 26) 2
                val () = need (slice text (localOffset + 30) localName = name, "zip local/central names disagree")
                val member = {name = name, method = unsigned text (at + 10) 2, size = unsigned text (at + 24) 4,
                              attributes = unsigned text (at + 38) 4} : zipped
            in loop (n - 1, at + 46 + length + extra + comment, member :: found) end
    in loop (count, start, []) end
  fun decode dir label command =
    let val output = dir ^ "/" ^ label
        val status = Children.exec {addressSpace = NONE, cpuTime = SOME 120, fileSize = SOME (64 * 1024 * 1024), core = SOME 0} (fn e => e)
          {cmd = command, dir = SOME root, stdin = "", stdout = output, stderr = output ^ ".err", timeout = 120}
    in need (status = 0, "archive decoder failed: " ^ firstNonEmpty (output ^ ".err")); binary output end
  fun memberNames expected actual = need (sort actual = sort expected, "archive member set differs")
  fun faults () =
    let fun rejects why f = need (((f (); false) handle Invalid _ => true), "archive checker accepted " ^ why)
        val () = rejects "truncated tar" (fn () => ignore (tar "short"))
        val () = rejects "truncated zip" (fn () => ignore (zip "PK"))
    in () end
end
