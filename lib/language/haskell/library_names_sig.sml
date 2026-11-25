(* The names of a program's library that the stages name (the haskell2010
   roadmap's D1 and D20): the prefix of its modules' identities, which is
   also its directory under rhc's share, and the module of each role a
   stage names by its Haskell 98 name: the Prelude (the translations,
   defaulting, the simplifier's folding of literals), PreludeText (the
   classes Read and Show of HsLint's tuples), Ix (derived Ix), Ratio (`:%`,
   which the simplifier folds) and rhc's leaf of primitives. The driver's
   descriptor of a library holds them (src/rhc/library.sml); a stage is
   given the program's.

   Area: Languages *)
signature HS_LIBRARY_NAMES =
sig
  (* A library's names. *)
  type t = {prefix : string,     (* its modules' identities are `prefix:M` *)
            prelude : string,    (* the module of the Prelude *)
            text : string,       (* the module of Read and Show *)
            ix : string,         (* the module of Ix *)
            ratio : string,      (* the module of Ratio *)
            builtin : string}    (* rhc's leaf of the primitives the library names *)

  (* The names of the library of Haskell 98, share/rhc/haskell98. *)
  val haskell98 : t

  (* `identity (t, m)` is the identity of the library's module `m`. *)
  val identity : t * string -> string

  (* `isLibrary (t, id)` is whether the identity `id` is of one of the
     library's modules. *)
  val isLibrary : t * string -> bool

  (* `entity (t, role, name)` is the key of the library's entity `name`
     of the module that `role` gives: `prefix:M.name`. *)
  val entity : t * (t -> string) * string -> string
end
