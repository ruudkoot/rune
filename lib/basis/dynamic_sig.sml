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
   through a structure of the program (a plugin). A virtual module, `structure
   X = _virtual : SIG`, is the same boundary inside one program: its
   implementation is the structure `X` that a unit before it exports, which
   the program's build file chooses (docs/build.md, Virtual modules).

   This signature is Rune's own.

   Area: The runtime

   Status: extension

   Deviation: `DYNAMIC/not-in-the-specification`. The Definition has no
   modules that come while a program runs.

   See also: `RUNTIME` *)
signature DYNAMIC =
sig
  (* `Mismatch` is raised where a module does not fit what the program was compiled against.

     That is a module loaded through `_dynamic` that was compiled against
     another signature than the program, or exports no structure, and a
     virtual module (`_virtual`) that has no implementation or one of
     another signature. Its argument names the file or the module, and both
     fingerprints. *)
  exception Mismatch of string

  (* `load file` loads the unit in `file` into the running program and runs
     its top level, as `Runtime.load file ()` does.

     Raises: `IO.Io` if the file cannot be read, and `Fail` if it is not a
     unit's file or names what no unit loaded exports. *)
  val load : string -> unit

  (* `reload file` loads the unit in `file` again, for every `_dynamic` declaration that loaded it.

     It runs the unit's top level, and each declaration's structure is then
     the new module's, so a call through it reaches the new code, and a
     function taken from it before is the old one. Where the new module
     implements another signature, nothing changes.

     A module whose signature has an abstract type is not loaded again: a
     value of the type that the program holds could be of another
     representation in the new module.

     Raises: `Mismatch` if no declaration loaded `file`, one did through a
     signature with an abstract type, or the new module implements another
     signature; `IO.Io` and `Fail` as `load`. *)
  val reload : string -> unit
end
