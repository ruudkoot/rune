(* Implements: HS_HEADER *)
structure HsHeader :> HS_HEADER =
struct
  type name = {name : string, at : int}

  (* each pragma of the header of src: the offset after its `{-#` and the
     offset of its `#-}` (or of its end, where the text ends inside it) *)
  fun pragmas (src : string) : (int * int) list =
    let
      val n = size src
      fun byte i = if i < n then Char.ord (String.sub (src, i)) else ~1
      (* past a nested comment opened before i, at depth d *)
      fun nested (i, d) =
        if i >= n then n
        else if byte i = 123 andalso byte (i + 1) = 45 then nested (i + 2, d + 1)
        else if byte i = 45 andalso byte (i + 1) = 125 then (if d = 1 then i + 2 else nested (i + 2, d - 1))
        else nested (i + 1, d)
      fun lineEnd i = if i >= n orelse byte i = 10 orelse byte i = 13 orelse byte i = 12 then i else lineEnd (i + 1)
      fun dashes i = if byte i = 45 then dashes (i + 1) else i
      fun white c = c = 32 orelse (c >= 9 andalso c <= 13)
      fun go (i, acc) =
        let val c = byte i
        in
          if c >= 0 andalso white c then go (i + 1, acc)
          (* a byte order mark at the head of the text, which the lexer
             takes for trivia *)
          else if i = 0 andalso c = 239 andalso byte 1 = 187 andalso byte 2 = 191 then go (3, acc)
          else if c = 123 andalso byte (i + 1) = 45 then
            let val j = nested (i + 2, 1)
            in
              if byte (i + 2) = 35 then
                go (j, (i + 3, if j - 3 >= i + 3 andalso byte (j - 3) = 35 then j - 3 else j) :: acc)
              else go (j, acc)
            end
          (* dashes that a symbol does not follow begin a line comment *)
          else if c = 45 andalso byte (i + 1) = 45
                  andalso (let val k = byte (dashes i) in k < 0 orelse k >= 128 orelse not (HsChar.isSymbol k) end)
          then go (lineEnd i, acc)
          else List.rev acc
        end
    in
      go (0, [])
    end

  (* the words of src from a to b, each with its offset: runs of what is
     neither white space nor a comma *)
  fun words (src, a, b) : name list =
    let
      fun sep c = Char.isSpace c orelse c = #","
      fun go (i, acc) =
        if i >= b then List.rev acc
        else if sep (String.sub (src, i)) then go (i + 1, acc)
        else
          let fun stop j = if j < b andalso not (sep (String.sub (src, j))) then stop (j + 1) else j
              val j = stop i
          in go (j, {name = String.substring (src, i, j - i), at = i} :: acc) end
    in
      go (a, [])
    end

  fun languages src =
    List.concat
      (List.map (fn (a, b) =>
                   case words (src, a, b) of
                     {name, ...} :: rest => if String.map Char.toUpper name = "LANGUAGE" then rest else []
                   | [] => [])
         (pragmas src))
end
