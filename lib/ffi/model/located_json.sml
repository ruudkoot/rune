(* JSON syntax stays in lib/json. This second walk associates validated
   JSON values and keys with byte offsets for sidecar diagnostics. *)
(* Implements: FOREIGN_JSON *)
structure ForeignJson :> FOREIGN_JSON =
struct
  type document = {file : string, text : string, value : Json.value,
                   values : (string list * int) list, keys : (string list * int) list}
  exception Error of ForeignModel.source * string
  fun source file text offset : ForeignModel.source =
    let fun go (i, line, start) = if i >= offset then {file = file, line = line, column = offset - start + 1}
          else if String.sub (text, i) = #"\n" then go (i + 1, line + 1, i + 1) else go (i + 1, line, start)
    in go (0, 1, 0) end
  fun decode {file, text} =
    let
      val value = Json.decode text handle Json.Syntax (offset, message) => raise Error (source file text offset, message)
      val values = ref ([] : (string list * int) list)
      val keys = ref ([] : (string list * int) list)
      val n = size text
      fun at i = String.sub (text, i)
      fun space i = if i < n andalso Char.isSpace (at i) then space (i + 1) else i
      fun quoted i = if at i = #"\\" then quoted (i + 2) else if at i = #"\"" then i + 1 else quoted (i + 1)
      fun walk path offset =
        let val i = space offset
            val () = values := (path, i) :: !values
        in case at i of
            #"{" => object path (i + 1)
          | #"[" => array path 0 (i + 1)
          | #"\"" => quoted (i + 1)
          | _ => let fun scalar j = if j = n orelse Char.isSpace (at j) orelse Char.contains ",]}" (at j) then j else scalar (j + 1)
                 in scalar i end
        end
      and object path offset =
        let val i = space offset
        in if at i = #"}" then i + 1 else
          let val finish = quoted (i + 1)
              val name = case Json.decode (String.substring (text, i, finish - i)) of Json.String s => s | _ => raise Fail "validated JSON key"
              val child = path @ [name]
              val () = keys := (child, i) :: !keys
              val ending = space (walk child (space finish + 1))
          in if at ending = #"," then object path (ending + 1) else ending + 1 end
        end
      and array path index offset =
        let val i = space offset
        in if at i = #"]" then i + 1 else
          let val ending = space (walk (path @ [Int.toString index]) i)
          in if at ending = #"," then array path (index + 1) (ending + 1) else ending + 1 end
        end
      val _ = walk [] 0
    in {file = file, text = text, value = value, values = rev (!values), keys = rev (!keys)} : document end
  fun value ({value,...}:document) = value
  fun location ({file, text, values, ...} : document) path =
    source file text (case List.find (fn (p, _) => p = path) values of SOME (_, at) => at | NONE => 0)
  fun error document path message = raise Error (location document path, message)
  fun object document path allowed (Json.Object fields) =
        let fun validate ([], _) = ()
              | validate ((name, _) :: rest, seen) =
                if List.exists (fn n => n = name) seen then
                  let val matches = List.filter (fn (p, _) => p = path @ [name]) (#keys document)
                      val at = case matches of _ :: (_, offset) :: _ => offset | (_, offset) :: _ => offset | [] => 0
                  in raise Error (source (#file document) (#text document) at, "duplicate field: " ^ name) end
                else if not (List.exists (fn n => n = name) allowed) then error document (path @ [name]) ("unknown field: " ^ name)
                else validate (rest, name :: seen)
        in validate (fields, []); fields end
    | object document path _ _ = error document path "expected an object"
  fun member document path fields name = case List.find (fn (n, _) => n = name) fields of
      SOME (_, value) => value | NONE => error document path ("missing field: " ^ name)
  fun optional fields name = Option.map #2 (List.find (fn (n, _) => n = name) fields)
  fun string document path (Json.String s) = s | string document path _ = error document path "expected a string"
  fun boolean document path (Json.Bool b) = b | boolean document path _ = error document path "expected a Boolean"
  fun array document path (Json.Array values) = values | array document path _ = error document path "expected an array"
end
