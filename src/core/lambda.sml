(* The lambda intermediate representation, which the translation makes from
   the elaborated syntax (docs/ir.md). Variables are integer stamps shared
   with elaboration, so every binder is globally unique. It is typed: a
   variable has the type its binder gives it, a use of a polymorphic one
   says at which instance (Inst), and what no argument's type tells -- a
   function's parameter, a constructor's datatype, a primitive's type, a
   constant's -- is written on the node; LambdaLint checks it. *)
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
    | Const of const * Ty.ty
    | Unit
    | Fn of int * Ty.ty * lexp            (* parameter, the function's type (an arrow), body *)
    | Inst of lexp * Ty.ty                (* a use of a variable at an instance of its scheme *)
    | App of lexp * lexp
    | Let of int * lexp * lexp            (* the variable has the type of what it is bound to *)
    | LetRec of (int * Ty.ty * lexp) list * lexp  (* every right-hand side is a Fn *)
    | Seq of lexp * lexp
    | SetGlobal of int * lexp             (* evaluates to unit *)
    | Tuple of lexp list
    | Select of int * lexp
    | Con0 of int * Ty.ty                 (* nullary constructor with tag, and the datatype it makes *)
    | Con of int * Ty.ty * lexp
    | Decon of int * lexp                 (* the argument of a value made by the constructor with the tag *)
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
    | ExnArg of Ty.ty * lexp              (* the payload of an exception, of the type its constructor gives it *)
    | Prim of string * Ty.ty option * lexp list  (* its type at this use; NONE where LambdaLint works it out *)
    | Mark of Source.span * lexp          (* where in the source this came from *)
    | Rest of lexp                        (* the rest of the program, after a declaration of its
                                             top level: where Mid's top level splits it *)

  (* The expression under whatever positions were put on it. Code that looks
     at the shape of an expression asks for this first. *)
  fun unmark (Mark (_, e)) = unmark e
    | unmark e = e

  val falseExp = Con0 (0, Ty.bool)
  val trueExp = Con0 (1, Ty.bool)

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
        | Const (c, _) => constToString c
        | Unit => "()"
        | Fn (x, _, b) => "(fn " ^ v x ^ " => " ^ go b ^ ")"
        | Inst (e, _) => go e
        | App (f, a) => "(" ^ go f ^ " " ^ go a ^ ")"
        | Let (x, a, b) => "let " ^ v x ^ " = " ^ go a ^ " in " ^ go b ^ " end"
        | LetRec (bs, b) =>
            "letrec " ^ String.concatWith " and " (List.map (fn (x, _, a) => v x ^ " = " ^ go a) bs) ^ " in " ^ go b ^ " end"
        | Seq (a, b) => "(" ^ go a ^ "; " ^ go b ^ ")"
        | SetGlobal (g, a) => "(g" ^ Int.toString g ^ " := " ^ go a ^ ")"
        | Tuple es => "(" ^ String.concatWith ", " (List.map go es) ^ ")"
        | Select (i, a) => "#" ^ Int.toString i ^ " " ^ go a
        | Con0 (t, _) => "C" ^ Int.toString t
        | Con (t, _, a) => "(C" ^ Int.toString t ^ " " ^ go a ^ ")"
        | Decon (_, a) => "decon " ^ go a
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
        | ExnArg (_, a) => "exnarg " ^ go a
        | Prim (p, _, args) => p ^ "(" ^ String.concatWith ", " (List.map go args) ^ ")"
        | Mark (_, e) => go e
        | Rest e => go e
    in go e end

  (* The same for a dump (--dump-after, tests/ir): one node to a line, its
     parts indented below it unless they are all atoms, positions left out,
     and variables and globals numbered afresh in the order they appear, so
     that what an expected dump says does not change with stamps made
     elsewhere. *)
  fun show (e : lexp) : string =
    let
      val vars : int IntMap.map ref = ref IntMap.empty
      val nvars = ref 0
      val globals : int IntMap.map ref = ref IntMap.empty
      val nglobals = ref 0
      fun number (m, count, x) =
        case IntMap.find (!m, x) of
          SOME n => n
        | NONE => (count := !count + 1; m := IntMap.insert (!m, x, !count); !count)
      val tyvars : int IntMap.map ref = ref IntMap.empty
      val ntyvars = ref 0
      fun v x = "v" ^ Int.toString (number (vars, nvars, x))
      fun g x = "g" ^ Int.toString (number (globals, nglobals, x))
      (* type variables too, as 'a, 'b, ... in the order they appear *)
      fun tyvar prefix x =
        let val n = number (tyvars, ntyvars, x)
        in if n <= 26 then prefix ^ String.str (Char.chr (Char.ord #"a" + n - 1)) else prefix ^ "t" ^ Int.toString n end
      val ty = Ty.format (tyvar "'", tyvar "'_")
      fun closeLast [] = []
        | closeLast ls = let val r = List.rev ls in List.rev ((hd r ^ ")") :: tl r) end
      fun atom e =
        case e of
          Var x => SOME (v x)
        | Global x => SOME (g x)
        | Const (c, _) => SOME (constToString c)
        | Unit => SOME "()"
        | Con0 (t, _) => SOME ("C" ^ Int.toString t)
        | Fail => SOME "fail"
        | NewExn n => SOME ("(newexn " ^ n ^ ")")
        | BuiltinExn k => SOME ("(builtinexn " ^ Int.toString k ^ ")")
        | Mark (_, e) => atom e
        | Rest e => atom e
        | _ => NONE
      fun isAtom e =
        case e of
          Var _ => true | Global _ => true | Const _ => true | Unit => true | Con0 _ => true
        | Fail => true | NewExn _ => true | BuiltinExn _ => true
        | Mark (_, e) => isAtom e
        | Rest e => isAtom e
        | _ => false
      fun indent n = CharVector.tabulate (n, fn _ => #" ")
      (* The lines of e at indentation n; the head of a node is named before
         its parts are, so that numbering follows the order of the text. *)
      fun lines (n, e) : string list =
        if isAtom e then [indent n ^ valOf (atom e)]
        else
            let
              fun node (head, parts) =
                let
                  val head = head ()
                in
                  if List.all isAtom parts then
                    [indent n ^ "(" ^ String.concatWith " " (head :: List.map (valOf o atom) parts) ^ ")"]
                  else
                    (indent n ^ "(" ^ head) :: closeLast (List.concat (List.map (fn p => lines (n + 2, p)) parts))
                end
            in
              case e of
                Inst (a, t) =>
                  if isAtom a then [indent n ^ "(inst " ^ valOf (atom a) ^ " : " ^ ty t ^ ")"]
                  else node (fn () => "inst : " ^ ty t, [a])
              | Fn (x, t, b) =>
                  node (fn () => case t of
                                   Ty.Arrow (d, r) => let val x = v x val d = ty d in "fn (" ^ x ^ " : " ^ d ^ ") : " ^ ty r end
                                 | _ => "fn " ^ v x ^ " : " ^ ty t,
                        [b])
              | App (f, a) => node (fn () => "app", [f, a])
              | Let (x, a, b) => node (fn () => "let " ^ v x, [a, b])
              | LetRec (bs, b) =>
                  node (fn () => "letrec " ^ String.concatWith " " (List.map (fn (x, _, _) => v x) bs),
                        List.map #3 bs @ [b])
              | Seq (a, b) => node (fn () => "seq", [a, b])
              | SetGlobal (x, a) => node (fn () => "set " ^ g x, [a])
              | Tuple es => node (fn () => "tuple", es)
              | Select (i, a) => node (fn () => "select " ^ Int.toString i, [a])
              | Con (t, _, a) => node (fn () => "con " ^ Int.toString t, [a])
              | Decon (t, a) => node (fn () => "decon " ^ Int.toString t, [a])
              | ConTag a => node (fn () => "tag", [a])
              | If (c, t, f) => node (fn () => "if", [c, t, f])
              | Try (a, b) => node (fn () => "try", [a, b])
              | Raise a => node (fn () => "raise", [a])
              | Handle (a, x, h) => node (fn () => "handle " ^ v x, [a, h])
              | MkExn (c, p) => node (fn () => "mkexn", [c, p])
              | ExnCon a => node (fn () => "exncon", [a])
              | ExnArg (t, a) =>
                  if isAtom a then [indent n ^ "(exnarg " ^ valOf (atom a) ^ " : " ^ ty t ^ ")"]
                  else node (fn () => "exnarg : " ^ ty t, [a])
              | Prim (p, _, args) => node (fn () => "prim " ^ p, args)
              | Mark (_, e) => lines (n, e)
              | Rest e => lines (n, e)
              | _ => [indent n ^ "?"]
            end
    in
      String.concatWith "\n" (lines (0, e))
    end

  (* The nodes of an expression, for --pass-stats. *)
  fun size (e : lexp) : int =
    case e of
      Fn (_, _, b) => 1 + size b
    | Inst (e, _) => size e
    | App (f, a) => 1 + size f + size a
    | Let (_, a, b) => 1 + size a + size b
    | LetRec (bs, b) => List.foldl (fn ((_, _, r), n) => n + size r) (1 + size b) bs
    | Seq (a, b) => 1 + size a + size b
    | SetGlobal (_, a) => 1 + size a
    | Tuple es => List.foldl (fn (e, n) => n + size e) 1 es
    | Select (_, a) => 1 + size a
    | Con (_, _, a) => 1 + size a
    | Decon (_, a) => 1 + size a
    | ConTag a => 1 + size a
    | If (c, t, f) => 1 + size c + size t + size f
    | Try (a, b) => 1 + size a + size b
    | Raise a => 1 + size a
    | Handle (a, _, h) => 1 + size a + size h
    | MkExn (c, p) => 1 + size c + size p
    | ExnCon a => 1 + size a
    | ExnArg (_, a) => 1 + size a
    | Prim (_, _, args) => List.foldl (fn (e, n) => n + size e) 1 args
    | Mark (_, a) => size a
    | Rest a => size a
    | _ => 1
end
