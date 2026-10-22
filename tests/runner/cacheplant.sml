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
  fun contentHash text =
    let val (a,b,c,d) = CharVector.foldl (fn (byte, (a,b,c,d)) =>
                let val x = Char.ord byte
                in ((a*31+x) mod 16777213, (b*37+x) mod 16777199,
                    (c*41+x) mod 16777183, (d*43+x) mod 16777153) end) (7,11,13,17) text
        fun hex n = let val value = String.map Char.toLower (Int.fmt StringCvt.HEX n)
                    in String.implode (List.tabulate (6-size value, fn _ => #"0")) ^ value end
    in String.concat (List.map hex [a,b,c,d]) end
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
  fun basisVersion file unit version =
    let val (outer, usages, rest) = parse file
        val (prefix, found) = Substring.position "RBI" (Substring.full rest)
    in if Substring.isEmpty found then false else
       let val at = Substring.size prefix
           val (_, afterVersion) = natural rest (at + 3)
           val (name, _) = stringAt rest afterVersion
       in if name <> unit then false else
            (publish file outer (usages ^ String.substring (rest, 0, at + 3) ^ encoded version ^ String.extract (rest, afterVersion, NONE)); true) end
    end
  fun command [old, new] = stale old new
    | command ("--basis-version" :: version :: unit :: files) =
        let val version = case IntInf.fromString version of SOME n => n | NONE => raise Invalid "invalid basis version"
            val changed = List.map (fn file => basisVersion file unit version) files
        in need (List.exists (fn value => value) changed, "no cache entry of " ^ unit) end
    | command _ = raise Invalid "usage: rune-cache-plant OLD NEW | --basis-version N UNIT ENTRY..."
end
