(* A family of Core's primitives, defined in a file of its own (the
   haskell98 roadmap, M17, M18): each primitive with its type, what the
   Core interpreter does for it, and the Mid function Core to Mid lowers it
   to, defined in the family's Mid text. CorePrim lists each family's
   primitives after its own, CoreInterp runs them and CoreToMid lowers
   them, so that a family is added with no edit of any of the three but a
   line of CorePrim's.

   A primitive of a family takes arguments of `!Int`, `!Str` and `!Bool`,
   and the state token where it is an action, and gives an `Int`, a `Str`
   or a `Bool`; an action gives `(utuple World T)` of one, or `World`.

   Area: Languages *)
signature CORE_PRIM_FAMILY =
sig
  (* An argument or a result of a primitive of a family. *)
  datatype value = Int of int | Str of string | Bool of bool | Unit

  (* What a primitive raises in the interpreter where it fails: an
     `IOError` of a code, a text, a file and a handle, as `exn_io_full`
     makes one. *)
  exception IOError of int * string * string * int

  (* A primitive: its name, its type, what it does, what the interpreter
     does for it, and the Mid function it is lowered to.

     Its type is Core's text. The interpreter's `run` is given its arguments,
     the state token left out; the Mid function takes them too, or `()`
     where it takes none. *)
  type prim = {name : string, ty : string, doc : string, run : value list -> value, mid : string}

  (* A family: its name, its primitives, and the Mid text that defines
     their functions.

     The text is a group of `funs`, which Core to Mid adds once to a program
     that names any of the family's primitives. *)
  type family = {name : string, prims : prim list, midText : string}
end
