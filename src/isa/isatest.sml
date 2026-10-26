(* The checks of the descriptions, held to what they refuse: `runeisa
   --test`, part of make check-isa. Each case is a description made wrong in
   one way -- a type a primitive cannot have, a register instruction whose
   operands, implicit traffic or order say what cannot be -- which the
   check must refuse (Isa.Bad), saying why; the descriptions themselves
   must pass. *)
structure IsaTest =
struct
  open Isa RegIsa

  (* a primitive of that arity and type *)
  fun prim (arity, ty) : primitive =
    {name = "test", arity = arity, ty = ty, doc = "", effects = [], group = ""}

  (* the register instructions with one of them changed *)
  fun changed (name, f) : rinstruction list =
    List.map (fn (i : rinstruction) => if #name i = name then f i else i) RegIsa.instructions

  fun withOperands ops ({name, flow, handlers, raises, implicit, order, primitives, doc, body, ...} : rinstruction)
      : rinstruction =
    {name = name, operands = ops, flow = flow, handlers = handlers, raises = raises, implicit = implicit,
     order = order, primitives = primitives, doc = doc, body = body}

  (* a new instruction, at the end *)
  fun added (i : rinstruction) = RegIsa.instructions @ [i]

  (* each case: what is wrong, a part of the message that refuses it, and
     the description that says it *)
  val types : (string * string * (unit -> unit)) list =
    [("a type missing", "has a type missing", fn () => ignore (parseTy "int * -> int")),
     ("a parenthesis not closed", "has a parenthesis not closed", fn () => ignore (parseTy "(int (int)) -> int")),
     ("more after the type", "goes on after its type", fn () => ignore (parseTy "int -> int)")),
     ("a character of no type", "has the character &", fn () => ignore (parseTy "int & int -> int")),
     ("a sequence applied to nothing", "applied to no type constructor", fn () => ignore (parseTy "(int, int) -> int")),
     ("a type cut short", "ends too soon", fn () => ignore (parseTy "int ->")),
     ("a primitive's type that cannot be read", "cannot be read", fn () => ignore (primType (prim (1, "int ->")))),
     ("arguments fewer than the arity", "another number of arguments", fn () => ignore (primType (prim (3, "int * int -> int")))),
     ("arguments more than the arity", "another number of arguments", fn () => ignore (primType (prim (2, "int * int * int -> int")))),
     ("an arity of none, from no unit", "another number of arguments", fn () => ignore (primType (prim (0, "int -> int")))),
     ("no function's type", "no function's", fn () => ignore (primType (prim (1, "int list"))))]

  val registers : (string * string * rinstruction list) list =
    [("an operand named twice", "has two operands d",
      changed ("MOVE", withOperands [("d", Writes (Like "d")), ("d", Reads any)])),
     ("an operand it has not", "names an operand q it has not",
      changed ("GLOBAL", withOperands [("d", Writes (GlobalOf "q")), ("g", K Global)])),
     ("a global that is a register", "names g as a global",
      changed ("SETGLOBAL", withOperands [("g", Reads any), ("s", Reads (GlobalOf "g"))])),
     ("a constant that is a tag", "names k as a constant", changed ("CONST", withOperands [("d", Writes (ConstOf "k")), ("k", K Tag)])),
     ("a primitive's result of no primitive", "names i as a primitive",
      changed ("INT", withOperands [("d", Writes (ResultOf "i")), ("i", K Immediate)])),
     ("a move that reads what it writes", "reads or leaves what another register holds",
      changed ("MOVE", withOperands [("d", Writes any), ("s", Reads (Like "d"))])),
     ("a written result", "writes what the function returns", changed ("RET", withOperands [("d", Writes Returned)])),
     ("what is left, where nothing is taken", "has what is left where it takes nothing",
      changed ("UNIT", withOperands [("d", Writes Left)])),
     ("parameters outside a list", "a function's parameters outside a list",
      changed ("CLOSURE", withOperands [("d", Writes (ParamsOf "f")), ("f", K Function), ("n", K Count), ("env", Registers (2, any))])),
     ("slots outside a list", "a closure's slots outside a list", changed ("SELF", withOperands [("d", Writes (CapturesOf "d"))])),
     ("the environment, and no closure read", "without reading the closure", changed ("ENV", implicitly [])),
     ("two registers written", "writes more than one register",
      changed ("MKEXN", withOperands [("d", Writes any), ("c", Writes any), ("x", Reads any)])),
     ("a register written not named d", "writes a register not named d", changed ("UNIT", withOperands [("r", Writes (Is RUnit))])),
     ("a list's length no count", "a list whose length is no count",
      changed ("TUPLE", withOperands [("d", Writes any), ("n", K Tag), ("fields", Registers (1, any))])),
     ("pushes of no primitive's arguments", "pushes a primitive's arguments it has not", changed ("TUPLE", implicitly [PushesArgs])),
     ("a result left for nothing after it", "leaves a value for no instruction after it", changed ("CALL", ordered [])),
     ("an exception taken that no raise leaves", "CATCH takes a value no instruction says is left", changed ("PUSHHANDLER", ordered [])),
     ("followed by what takes nothing", "is followed by MOVE, which takes nothing",
      changed ("CALLK", ordered [Then "RESULT", Then "MOVE"])),
     ("followed by no instruction", "is followed by NOTHING, which is no instruction",
      changed ("CALLK", ordered [Then "RESULT", Then "NOTHING"])),
     ("followed by what takes, leaving nothing", "is followed by RESULT, and leaves nothing for it",
      changed ("TAILCALL", ordered [Then "RESULT"])),
     ("a table of what does not jump", "a table of MOVE, which does not jump", changed ("SWITCH", ordered [Table ("n", "MOVE")])),
     ("a table of no count", "names s as a count", changed ("SWITCH", ordered [Table ("s", "JUMP")])),
     ("a handler at no handler's label", "names o as a handler's label",
      changed ("PUSHHANDLER", ordered [Begins ("o", "CATCH")] o withOperands [("o", K Label)])),
     ("a handler beginning with what takes nothing", "begins with MOVE, which takes nothing",
      changed ("PUSHHANDLER", ordered [Begins ("o", "MOVE")])),
     ("image primitives of no primitive", "says which primitives it names, and names none", changed ("TUPLE", naming Images)),
     ("a closure of what is no function", "names d as a function", changed ("CLOSURE", implicitly [MakesClosure "d"])),
     ("a closure that captures for another", "makes a closure of another function than it captures for",
      changed ("CLOSURE", implicitly [MakesClosure "f"]
                          o withOperands [("d", Writes (Is RPtr)), ("f", K Function), ("g", K Function), ("n", K Count),
                                          ("env", Registers (3, CapturesOf "g"))])),
     ("a closure that captures nothing for it", "makes a closure without capturing for it",
      changed ("CALLK", implicitly [MakesClosure "f", Leaves (ReturnOf "f")])),
     ("a call of a closure it does not read", "calls a closure it does not read", changed ("UNIT", implicitly [CallsClosure])),
     ("a known call without the parameters", "calls a function without its parameters",
      changed ("CLOSURE", implicitly [CallsKnown "f"])),
     ("a known call with another's parameters", "calls a function with another's parameters",
      changed ("TAILCALLK", implicitly [CallsKnown "f"]
                            o withOperands [("f", K Function), ("g", K Function), ("n", K Count), ("args", Registers (2, ParamsOf "g"))])),
     ("an instruction described twice", "HALT is described twice", added (List.hd RegIsa.instructions))]

  (* NONE where f is refused with a message that says why *)
  fun refused (what, why, f) =
    (f (); SOME ("not refused: " ^ what))
    handle Bad msg => if String.isSubstring why msg then NONE
                      else SOME ("refused for another reason: " ^ what ^ ": " ^ msg)

  (* what failed: nothing, where every case is refused and the descriptions pass *)
  fun run () : string list =
    let
      val passes =
        (Isa.check (StackIsa.instructions, PrimIsa.primitives); RegIsa.check RegIsa.instructions; [])
        handle Bad msg => ["the descriptions are refused: " ^ msg]
    in
      passes
      @ List.mapPartial refused types
      @ List.mapPartial (fn (what, why, instrs) => refused (what, why, fn () => RegIsa.check instrs)) registers
    end

  val count = List.length types + List.length registers
end
