(* ZmtpWire: ZMTP 3.1's greeting, frames and metadata.

   Implements: ZMTP_WIRE *)
structure ZmtpWire :> ZMTP_WIRE =
struct
  type peer = {major : int, minor : int, mechanism : string, server : bool}
  datatype frame = Data of {more : bool, body : string} | Command of {name : string, data : string}
  exception Malformed of string

  fun zeros n = CharVector.tabulate (n, fn _ => #"\000")

  fun greeting {mechanism, server} =
    "\255" ^ zeros 8 ^ "\127" ^ "\003\001" ^ mechanism ^ zeros (20 - size mechanism)
    ^ (if server then "\001" else "\000") ^ zeros 31

  fun byte (s, i) = Char.ord (String.sub (s, i))

  fun readGreeting s =
    if size s <> 64 orelse byte (s, 0) <> 255 orelse byte (s, 9) <> 127 orelse byte (s, 10) < 3 then NONE
    else
      let
        val m = String.substring (s, 12, 20)
        fun len k = if k > 0 andalso String.sub (m, k - 1) = #"\000" then len (k - 1) else k
      in
        SOME {major = byte (s, 10), minor = byte (s, 11), mechanism = String.substring (m, 0, len 20),
              server = byte (s, 32) = 1}
      end

  (* n in k bytes, the most significant first *)
  fun bigEndian (n, k) =
    CharVector.tabulate (k, fn i => Char.chr (IntInf.toInt (IntInf.andb (IntInf.~>> (IntInf.fromInt n, Word.fromInt (8 * (k - 1 - i))), 255))))

  fun encode f =
    let
      val (flags, body) =
        case f of
          Data {more, body} => (if more then 1 else 0, body)
        | Command {name, data} => (4, String.str (Char.chr (size name)) ^ name ^ data)
      val n = size body
    in
      if n < 256 then String.implode [Char.chr flags, Char.chr n] ^ body
      else String.str (Char.chr (flags + 2)) ^ bigEndian (n, 8) ^ body
    end

  fun message parts =
    let
      fun go ([], acc) = String.concat (rev acc)
        | go ([p], acc) = go ([], encode (Data {more = false, body = p}) :: acc)
        | go (p :: rest, acc) = go (rest, encode (Data {more = true, body = p}) :: acc)
    in
      go (parts, [])
    end

  type reader = string
  val reader = ""

  fun number (s, i, k) =
    let fun go (j, n) = if j = k then n else go (j + 1, n * 256 + byte (s, i + j))
    in go (0, 0) end
    handle Overflow => raise Malformed "a frame larger than this system holds"

  fun feed (buf, more) =
    let
      val s = buf ^ more
      fun go (i, acc) =
        if i + 2 > size s then (rev acc, String.extract (s, i, NONE))
        else
          let
            val flags = byte (s, i)
            val long = Word.andb (Word.fromInt flags, 0w2) <> 0w0
            val head = if long then 9 else 2
          in
            if i + head > size s then (rev acc, String.extract (s, i, NONE))
            else
              let
                val n = if long then number (s, i + 1, 8) else byte (s, i + 1)
                val () = if n > String.maxSize then raise Malformed "a frame larger than a string" else ()
              in
                if i + head + n > size s then (rev acc, String.extract (s, i, NONE))
                else
                  let
                    val body = String.substring (s, i + head, n)
                    val f =
                      if Word.andb (Word.fromInt flags, 0w4) <> 0w0 then
                        let val k = if n = 0 then raise Malformed "a command without a name" else byte (body, 0)
                        in
                          if 1 + k > n then raise Malformed "a command whose name runs past it"
                          else Command {name = String.substring (body, 1, k), data = String.extract (body, 1 + k, NONE)}
                        end
                      else Data {more = Word.andb (Word.fromInt flags, 0w1) <> 0w0, body = body}
                  in
                    go (i + head + n, f :: acc)
                  end
              end
          end
    in
      go (0, [])
    end

  fun ready props =
    Command {name = "READY",
             data = String.concat (map (fn (k, v) => String.str (Char.chr (size k)) ^ k ^ bigEndian (size v, 4) ^ v) props)}

  fun properties d =
    let
      fun go (i, acc) =
        if i >= size d then rev acc
        else
          let
            val k = byte (d, i)
            val () = if i + 1 + k + 4 > size d then raise Malformed "metadata cut short" else ()
            val name = String.substring (d, i + 1, k)
            val n = number (d, i + 1 + k, 4)
            val at = i + 1 + k + 4
            val () = if at + n > size d then raise Malformed "a value cut short" else ()
          in
            go (at + n, (name, String.substring (d, at, n)) :: acc)
          end
    in
      go (0, [])
    end
end
