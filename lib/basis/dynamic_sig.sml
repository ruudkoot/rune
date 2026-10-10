(* Dynamic modules: units of code that a program loads while it runs
   (docs/units.md, Dynamic modules).

   A program declares `structure X = _dynamic "path" : SIG` and is compiled
   against the signature alone; a module declares `_export structure Y :
   SIG = ...` and is compiled to a unit's file (`rune --units --emit-units`).
   When the program reaches the declaration, the unit at `path` is loaded,
   its top level runs, and `X` is what it exported, where the module was
   compiled against the same signature: a constructor's tag is its place in
   the signature's datatype, a type the signature leaves abstract stays
   abstract, and an exception the module raises is the program's to
   handle. A program that loads a module is built in units (`rune
   --units`), whose units the module links against.

   `Dynamic.load` is the untyped form: a unit that registers what it offers
   through a structure of the program (a plugin).

   This signature is Rune's own.

   Area: The runtime

   Status: extension

   Deviation: `DYNAMIC/not-in-the-specification`. The Definition has no
   modules that come while a program runs.

   See also: `RUNTIME` *)
signature DYNAMIC =
sig
  (* `Mismatch` is raised where a module loaded through `_dynamic` was
     compiled against another signature than the program, or exports no
     structure. Its argument names the file and both fingerprints. *)
  exception Mismatch of string

  (* `load file` loads the unit in `file` into the running program and runs
     its top level, as `Runtime.load file ()` does.

     Raises: `IO.Io` if the file cannot be read, and `Fail` if it is not a
     unit's file or names what no unit loaded exports. *)
  val load : string -> unit
end
