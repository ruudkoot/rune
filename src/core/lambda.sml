(* Untyped lambda intermediate representation. Variables are integer stamps
   shared with elaboration, so every binder is globally unique. *)
structure Lambda =
struct
  datatype const =
      CInt of IntInf.int
    | CWord of IntInf.int
    | CReal of string                     (* SML literal text *)
    | CString of string
    | CChar of int

  datatype lexp =
      Var of int                          (* local variable *)
    | Global of int                       (* top-level variable *)
    | Const of const
    | Unit
    | Fn of int * lexp                    (* parameter, body *)
    | App of lexp * lexp
    | Let of int * lexp * lexp
    | LetRec of (int * lexp) list * lexp  (* every right-hand side is a Fn *)
    | Seq of lexp * lexp
    | SetGlobal of int * lexp             (* evaluates to unit *)
    | Tuple of lexp list
    | Select of int * lexp
    | Con0 of int                         (* nullary constructor with tag *)
    | Con of int * lexp
    | Decon of lexp
    | ConTag of lexp
    | If of lexp * lexp * lexp
    | Try of lexp * lexp                  (* body, fallback taken when body executes Fail *)
    | Fail
    | Raise of lexp
    | Handle of lexp * int * lexp         (* body, variable bound to the exception, handler *)
    | NewExn of string
    | BuiltinExn of int
    | MkExn of lexp * lexp                (* constructor, payload *)
    | ExnCon of lexp
    | ExnArg of lexp
    | Prim of string * lexp list

  val falseExp = Con0 0
  val trueExp = Con0 1

  (* Builtin exception constructor numbers (see docs/bytecode.md). *)
  val exnMatch = 0
  val exnBind = 1

  fun raiseBuiltin k = Raise (MkExn (BuiltinExn k, Unit))

  fun constToString c =
    case c of
      CInt i => IntInf.toString i
    | CWord w => "0w" ^ IntInf.toString w
    | CReal r => r
    | CString s => "\"" ^ String.toString s ^ "\""
    | CChar c => "#\"" ^ Char.toString (Char.chr c) ^ "\""

  fun toString (e : lexp) : string =
    let
      fun v i = "v" ^ Int.toString i
      fun go e =
        case e of
          Var i => v i
        | Global i => "g" ^ Int.toString i
        | Const c => constToString c
        | Unit => "()"
        | Fn (x, b) => "(fn " ^ v x ^ " => " ^ go b ^ ")"
        | App (f, a) => "(" ^ go f ^ " " ^ go a ^ ")"
        | Let (x, a, b) => "let " ^ v x ^ " = " ^ go a ^ " in " ^ go b ^ " end"
        | LetRec (bs, b) =>
            "letrec " ^ String.concatWith " and " (List.map (fn (x, a) => v x ^ " = " ^ go a) bs) ^ " in " ^ go b ^ " end"
        | Seq (a, b) => "(" ^ go a ^ "; " ^ go b ^ ")"
        | SetGlobal (g, a) => "(g" ^ Int.toString g ^ " := " ^ go a ^ ")"
        | Tuple es => "(" ^ String.concatWith ", " (List.map go es) ^ ")"
        | Select (i, a) => "#" ^ Int.toString i ^ " " ^ go a
        | Con0 t => "C" ^ Int.toString t
        | Con (t, a) => "(C" ^ Int.toString t ^ " " ^ go a ^ ")"
        | Decon a => "decon " ^ go a
        | ConTag a => "tag " ^ go a
        | If (c, t, f) => "(if " ^ go c ^ " then " ^ go t ^ " else " ^ go f ^ ")"
        | Try (a, b) => "(try " ^ go a ^ " else " ^ go b ^ ")"
        | Fail => "FAIL"
        | Raise a => "(raise " ^ go a ^ ")"
        | Handle (a, x, h) => "(" ^ go a ^ " handle " ^ v x ^ " => " ^ go h ^ ")"
        | NewExn n => "newexn " ^ n
        | BuiltinExn k => "builtinexn " ^ Int.toString k
        | MkExn (c, p) => "(mkexn " ^ go c ^ " " ^ go p ^ ")"
        | ExnCon a => "exncon " ^ go a
        | ExnArg a => "exnarg " ^ go a
        | Prim (p, args) => p ^ "(" ^ String.concatWith ", " (List.map go args) ^ ")"
    in go e end
end
