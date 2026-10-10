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

  fun load (path : string, fingerprint : string) : 'a =
    let
      val () = exported := NONE
      val () = Runtime.load path ()
    in
      case !exported of
        SOME (f, slots) =>
          (exported := NONE;
           if f = fingerprint then cast slots
           else raise Mismatch (path ^ " implements another signature (" ^ f ^ ") than the program wants (" ^ fingerprint ^ ")"))
      | NONE => raise Mismatch (path ^ " exports no structure (_export)")
    end
end

structure Dynamic : DYNAMIC =
struct
  exception Mismatch = RuneDynamic.Mismatch
  fun load file = Runtime.load file ()
end
