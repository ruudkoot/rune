structure BuildOptions =
struct
  open BuildCommon
  datatype kind=Value | Flag | Many of bool
  fun parse specs defaults args =
    let fun spec name=case List.find (fn (key,_) => key=name) specs of SOME (_,kind) => kind | NONE => raise Usage ("unknown option " ^ name)
        fun set key values options=(key,values)::List.filter (fn (old,_) => old<>key) options
        fun take [] acc=(List.rev acc,[]) | take (rest as word::words) acc=if String.isPrefix "--" word then (List.rev acc,rest) else take words (word::acc)
        fun loop [] options=options | loop (word::rest) options =
          let val (name,inline)=case Substring.position "=" (Substring.full word) of (a,b) =>
                 if Substring.isEmpty b then (word,NONE) else (Substring.string a,SOME (Substring.string (Substring.triml 1 b)))
          in case spec name of Flag => (need (not (isSome inline),"flag takes no value: " ^ name);loop rest (set name ["true"] options))
             | Value => (case inline of SOME value => loop rest (set name [value] options)
                           | NONE => case rest of value::tail => loop tail (set name [value] options) | _ => raise Usage ("missing value for " ^ name))
             | Many required =>
                 let val (values,rest)=take rest [] val values=(case inline of NONE => [] | SOME v => [v]) @ values
                 in need (not required orelse not (null values),"missing values for " ^ name);loop rest (set name values options) end end
    in loop args (List.map (fn (key,value) => (key,[value])) defaults) end
  fun values options key=case List.find (fn (name,_) => name=key) options of SOME (_,v) => v | NONE => []
  fun get options key default=case values options key of first::_ => first | [] => default
  fun require options key=let val value=get options key "" in if value="" then raise Usage ("missing " ^ key) else value end
  fun flag options key=get options key "false"="true"
end
