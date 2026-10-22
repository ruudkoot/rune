(* Stable legacy transcript spelling: recursively sorted objects, ASCII
   escapes and spaced separators, independent of transport chunk boundaries. *)
structure ProtocolJson =
struct
  fun quoted text =
    let fun hex n="\\u" ^ StringCvt.padLeft #"0" 4 (String.map Char.toLower (Int.fmt StringCvt.HEX n))
        fun point cp=case cp of 8 => "\\b" | 9 => "\\t" | 10 => "\\n" | 12 => "\\f" | 13 => "\\r"
          | 34 => "\\\"" | 92 => "\\\\"
          | _ => if cp<32 orelse cp>=127 then
                   if cp<=65535 then hex cp else
                     let val n=cp-65536 in hex (55296+n div 1024) ^ hex (56320+n mod 1024) end
                 else str (Char.chr cp)
    in "\"" ^ String.concat (List.rev (Utf8.foldl (fn (cp,parts) => point cp :: parts) [] text)) ^ "\"" end
  fun sorted (fields : (string * Json.value) list) =
    let fun insert (row as (key,_)) []=[row]
          | insert (row as (key,_)) (first as (other,_) :: rest)=if key<other then row :: first else hd first :: insert row rest
    in List.foldl (fn (row,fields) => insert row fields) [] fields end
  fun encode Json.Null="null"
    | encode (Json.Bool value)=Bool.toString value
    | encode (Json.Number value)=value
    | encode (Json.String value)=quoted value
    | encode (Json.Array values)="[" ^ String.concatWith ", " (List.map encode values) ^ "]"
    | encode (Json.Object fields)="{" ^ String.concatWith ", " (List.map (fn (key,value) => quoted key ^ ": " ^ encode value) (sorted fields)) ^ "}"
  fun field key value=Json.member (key,value)
  fun text (SOME (Json.String text))=SOME text | text _=NONE
  fun integer (SOME value)=Json.toInt value | integer NONE=NONE
  fun implementation (Json.Object fields)=
        Json.Object (List.map (fn ("result",Json.Object fields) =>
              ("result",Json.Object (List.map (fn ("implementation",Json.String text) =>
                    let val prefix=Substring.string (#1 (Substring.position " " (Substring.full text)))
                    in ("implementation",Json.String (prefix ^ " VERSION")) end | value => value) fields))
              | value => value) fields)
    | implementation value=value
end
