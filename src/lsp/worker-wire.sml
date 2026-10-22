(* Private worker values preserve arbitrary native filename/source bytes.
   They are framed with Framing.ContentLength, independently of LSP JSON. *)
structure RuneLspWorkerWire =
struct
  datatype value=Null | Bool of bool | Integer of IntInf.int | Bytes of string
    | Array of value list | Object of (string*value) list
  exception Invalid of string
  val maximum=128*1024*1024
  fun length n =
    if n<0 orelse n>maximum then raise Invalid "worker field exceeds byte limit" else
    String.implode (List.map (fn shift => Char.chr ((n div shift) mod 256)) [16777216,65536,256,1])
  fun chunks value =
    let val items=ref 0
        fun string text=length (size text) :: [text]
        fun encode depth value=
          if depth>64 then raise Invalid "worker value exceeds nesting limit" else
          (items:= !items+1;if !items>1000000 then raise Invalid "too many worker values" else ();
          case value of Null => ["n"] | Bool false => ["f"] | Bool true => ["t"]
          | Integer n => "i" :: string (IntInf.toString n)
          | Bytes text => "s" :: string text
          | Array values => "a" :: length (List.length values) :: List.concat (List.map (encode (depth+1)) values)
          | Object fields => "o" :: length (List.length fields) ::
              List.concat (List.map (fn (key,value) => string key @ encode (depth+1) value) fields))
        val pieces="RW1" :: encode 0 value
        val total=List.foldl (fn (piece,total) => if size piece>maximum-total then
          raise Invalid "worker message exceeds byte limit" else total+size piece) 0 pieces
    in (total,pieces) end
  fun encode value=String.concat (#2 (chunks value))
  fun decode text =
    let val n=size text
        val ()=if n>maximum then raise Invalid "worker message exceeds byte limit" else ()
        val offset=ref 0
        val items=ref 0
        fun take count=if count<0 orelse count>n- !offset then raise Invalid "truncated worker value" else
          String.substring (text,!offset,count) before offset:= !offset+count
        fun byte ()=Char.ord (String.sub (take 1,0))
        fun count limit =
          let fun loop (0,value)=value
                | loop (left,value)=
                    let val digit=byte ()
                    in if value>limit div 256 orelse value=limit div 256 andalso digit>limit mod 256
                       then raise Invalid "worker count exceeds limit" else loop (left-1,value*256+digit) end
          in loop (4,0) end
        fun string ()=take (count maximum)
        fun read depth =
          if depth>64 then raise Invalid "worker value exceeds nesting limit" else
          let val ()=items:= !items+1
              val ()=if !items>1000000 then raise Invalid "too many worker values" else ()
              fun list (count,read) =
                let fun loop (0,all)=List.rev all | loop (n,all)=loop (n-1,read () :: all)
                in loop (count,[]) end
          in case take 1 of "n" => Null | "f" => Bool false | "t" => Bool true
            | "s" => Bytes (string ())
            | "i" =>
                let val text=string ()
                in case IntInf.fromString text of SOME value =>
                     if IntInf.toString value=text then Integer value else raise Invalid "noncanonical worker integer"
                   | NONE => raise Invalid "invalid worker integer" end
            | "a" => Array (list (count 1000000,fn () => read (depth+1)))
            | "o" => Object (list (count 1000000,fn () => let val key=string () in (key,read (depth+1)) end))
            | _ => raise Invalid "unknown worker value tag" end
        val ()=if take 3="RW1" then () else raise Invalid "wrong worker protocol version"
        val value=read 0
    in if !offset=n then value else raise Invalid "trailing worker data" end
  fun object (Object fields)=fields | object _=raise Invalid "expected worker object"
  fun field (value,key)=
    case List.filter (fn (name,_) => name=key) (object value) of
      [(_,value)] => value | [] => raise Invalid ("missing worker field: " ^ key)
    | _ => raise Invalid ("duplicate worker field: " ^ key)
  fun bytes (Bytes value)=value | bytes _=raise Invalid "expected worker bytes"
  fun integer (Integer value)=value | integer _=raise Invalid "expected worker integer"
  fun boolean (Bool value)=value | boolean _=raise Invalid "expected worker boolean"
  fun array (Array values)=values | array _=raise Invalid "expected worker array"
  fun json value=Bytes (Json.encode value)
  fun unjson value=Json.decode (bytes value)
end
