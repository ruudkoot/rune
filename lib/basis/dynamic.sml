(* Dynamic modules (docs/units.md, Dynamic modules; the incremental roadmap's
   M9, D17 and D18): RuneDynamic is the boundary that a program's `_dynamic`
   and `_virtual` and a module's `_export` compile to. A module's top level
   ends by handing its slots, as a tuple, and the fingerprint of its
   signature's ABI to export; load runs the module's unit and takes what it
   handed, where the fingerprints agree. The slots cross as units: what a slot holds does not
   change with the type it is given, and the fingerprints say the two sides
   give the same. *)
structure RuneDynamic =
struct
  exception Mismatch of string
  val cast = _prim "unsafe_cast" : 'a -> 'b
  val exported : (string * unit) option ref = ref NONE
  (* what the program's modules exported, by name, the last first: a virtual
     module's implementation is the one of its name (docs/build.md) *)
  val named : (string * (string * unit)) list ref = ref []

  fun export (name : string, fingerprint : string, slots : 'a) : unit =
    (exported := SOME (fingerprint, cast slots);
     named := (name, (fingerprint, cast slots)) :: !named)

  fun take (name : string, fingerprint : string) : 'a =
    case List.find (fn (n, _) => n = name) (!named) of
      SOME (_, (f, slots)) =>
        if f = fingerprint then cast slots
        else raise Mismatch ("the implementation of the virtual module " ^ name ^ " implements another signature ("
                             ^ f ^ ") than the program wants (" ^ fingerprint ^ ")")
    | NONE => raise Mismatch ("the virtual module " ^ name ^ " has no implementation (implements " ^ name
                              ^ " = ... end, before it in the build file)")

  (* the unit at path run, and what it exported, where the fingerprints
     agree, given to set, which sets the slots of the declaration *)
  fun run (path : string, fingerprint : string, set : 'a -> unit) : unit =
    let
      val () = exported := NONE
      val () = Runtime.load path ()
    in
      case !exported of
        SOME (f, slots) =>
          (exported := NONE;
           if f = fingerprint then set (cast slots)
           else raise Mismatch (path ^ " implements another signature (" ^ f ^ ") than the program wants (" ^ fingerprint ^ ")"))
      | NONE => raise Mismatch (path ^ " exports no structure (_export)")
    end

  (* the declarations that loaded each file, the last first, as they load
     it again: NONE for one whose signature has an abstract type *)
  val loaded : (string * (unit -> unit) option) list ref = ref []

  fun load (path : string, fingerprint : string, reloadable : bool, set : 'a -> unit) : unit =
    (run (path, fingerprint, set);
     loaded := (path, if reloadable then SOME (fn () => run (path, fingerprint, set)) else NONE) :: !loaded)

  (* Dynamic.reload: the file loaded again for every declaration that loaded
     it, each declaration's slots set to the new module's *)
  fun reload (path : string) : unit =
    case List.filter (fn (p, _) => p = path) (!loaded) of
      [] => raise Mismatch (path ^ " was loaded by no _dynamic declaration")
    | ds =>
        if List.exists (fn (_, again) => not (isSome again)) ds
        then raise Mismatch (path ^ " is loaded through a signature with an abstract type, whose values the program holds"
                             ^ " could be of another representation in the new module: it is not reloaded")
        else List.app (fn (_, again) => valOf again ()) (List.rev ds)
end

structure Dynamic : DYNAMIC =
struct
  exception Mismatch = RuneDynamic.Mismatch
  fun load file = Runtime.load file ()
  val reload = RuneDynamic.reload
end
