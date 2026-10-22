(* The names a compile looks up, while `recording`: the first of each long
   name, by its kind -- "v" a value, "t" a type, "s" a structure (Env),
   "sig" a signature and "fun" a functor (Elaborate), "fix" an identifier's
   fixity (Fixity, as the parser reads it) -- in whatever environment it is
   looked up. What a unit's compile depends on of the units before it is
   among them (the usages of the cache: UnitCache, docs/units.md). *)
structure Usage =
struct
  val recording = ref false
  val used : unit StringMap.map ref = ref StringMap.empty

  fun use (kind : string, name : string) : unit =
    if !recording then used := StringMap.insert (!used, kind ^ " " ^ name, ()) else ()

  (* f () recorded: its result, and the names it looked up, each once *)
  fun record (f : unit -> 'a) : 'a * string list =
    let
      val () = (recording := true; used := StringMap.empty)
      val r = f () handle e => (recording := false; raise e)
    in recording := false; (r, StringMap.listKeys (!used)) end
end
