(* The evidence records of Haskell 98's checker (the haskell98 roadmap's
   D31, M13): what inference chose at each node of the renamed tree, by
   node, in the manner of Rune's `Witness` (lib/compiler/elab/witness.sml),
   for desugaring to Core (M15) to translate and HsLint (M16, D54) to
   check: each overloaded use's dictionaries, each binder's type and the
   dictionary parameters it is abstracted over, each instance's
   dictionaries, and each defaulting, with what it chose from.

   A type here is closed: a constructor applied to types and the type
   variables of schemes, signatures and instance heads, each a rigid
   variable with a name unique to the program (`HsTypes.TRigid`); a
   scheme's variables are those names. A dictionary is Faxén's `dict`
   judgement made explicit: a parameter in scope, an instance's dictionary
   function at the types of its head's variables applied to the
   dictionaries of its context ("dict inst"), or a superclass's taken from
   a dictionary of its subclass ("dict super").

   A node is the kind of record and the span of the node of the renamed
   tree it belongs to, `KIND@FILE:START-STOP`: the name of a variable or a
   constructor where it is used or bound, a literal, a negation, an
   enumeration, a `do`, a pattern, an instance declaration.

   Area: Languages *)
signature HS_EVIDENCE =
sig
  (* A dictionary. *)
  datatype dict =
      DParam of string                                  (* a dictionary parameter, by name *)
    | DInst of {inst : string, tys : HsTypes.ty list, args : dict list}
                                                        (* an instance, at its head's variables, of its context's dictionaries *)
    | DSuper of {dict : dict, cls : string, super : string}
                                                        (* the dictionary of `super`, a superclass of `cls`, in one of `cls` *)

  (* A scheme as the records hold it: its variables by name, its context
     and its type, over those names. *)
  type scheme = {vars : string list, ctx : HsTypes.pred list, ty : HsTypes.ty}

  (* A record. *)
  datatype record =
      (* a variable or a constructor used: the types its scheme's
         variables are instantiated at, in order, and the dictionaries of
         its context, in order *)
      Use of {tys : HsTypes.ty list, dicts : dict list}
      (* a construct the Report translates through a class, at a type:
         a numeric literal (`fromInteger`: Num; `fromRational`:
         Fractional), a negation (`negate`: Num), an enumeration (Enum), a
         `do` (Monad), a numeric literal pattern (Eq and Num) or an n+k
         pattern (Integral); each dictionary by its class *)
    | Overloaded of {ty : HsTypes.ty, dicts : (string * dict) list}
      (* a binder generalised: its scheme, and the dictionary parameters
         it is abstracted over, one for each predicate of the scheme's
         context, in order *)
    | Binding of {scheme : scheme, params : string list}
      (* a binder not generalised, of a lambda, a case, a generator, a
         restricted group, or an instance's method: its type *)
    | Mono of HsTypes.ty
      (* an instance declaration: its head's variables, the dictionary
         parameters of its context, in order, and the dictionaries of its
         class's direct superclasses at its type, in the class's order *)
    | Instance of {inst : string, vars : string list, params : string list, supers : dict list}
      (* a class declaration's default methods: the dictionary parameter
         of the class *)
    | Class of {param : string}
      (* a type variable defaulted (4.3.4): its predicates, the types the
         `default` in force offers, from the module named, and the type
         chosen *)
    | Defaulted of {var : string, preds : HsTypes.pred list, candidates : HsTypes.ty list, module_ : string,
                    choice : HsTypes.ty}

  (* `node (kind, span)` is the key of a node. *)
  val node : string * HsSource.span -> string

  (* A table of records by node. *)
  type table

  (* `empty ()` is a new table with no record. *)
  val empty : unit -> table
  (* `add (t, node, r)` adds the record `r` at `node`, after any there. *)
  val add : table * string * record -> unit
  (* `find (t, node)` is the records at `node`, in the order added. *)
  val find : table * string -> record list

  (* `all t` is every record, by node, in the order of the nodes' keys. *)
  val all : table -> (string * record list) list

  (* `showDict d` and `showRecord r` are as a dump prints them. *)
  val showDict : dict -> string
  val showRecord : record -> string
end
