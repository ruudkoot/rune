(* Implements: HS_USAGE *)
structure HsUsage :> HS_USAGE =
struct
  datatype read =
      Name of {within : string, space : string, qual : string, name : string}
    | Item of {from : string, space : string, name : string}
    | Exports of string
    | Instance of {cls : string, tycon : string}
    | Standard of {space : string, name : string}
    | Entity of string

  val note : (read -> unit) ref = ref (fn _ => ())

  fun setNote f = !note before note := f

  fun read r = !note r

  (* fields apart by a space, which no name, identity or key holds *)
  fun join ws = String.concatWith " " ws

  fun key r =
    case r of
      Name {within, space, qual, name} => join ["name", within, space, qual, name]
    | Item {from, space, name} => join ["item", from, space, name]
    | Exports m => join ["exports", m]
    | Instance {cls, tycon} => join ["instance", cls, tycon]
    | Standard {space, name} => join ["standard", space, name]
    | Entity k => join ["entity", k]

  fun fromKey s =
    case String.fields (fn c => c = #" ") s of
      ["name", within, space, qual, name] => SOME (Name {within = within, space = space, qual = qual, name = name})
    | ["item", from, space, name] => SOME (Item {from = from, space = space, name = name})
    | ["exports", m] => SOME (Exports m)
    | ["instance", cls, tycon] => SOME (Instance {cls = cls, tycon = tycon})
    | ["standard", space, name] => SOME (Standard {space = space, name = name})
    | ["entity", k] => SOME (Entity k)
    | _ => NONE
end
