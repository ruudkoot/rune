(* 4.7: a constructor applied to a value is non-expansive where the
   constructor is in parentheses with a type, `(conexp : ty) atexp`, nested
   or not, op'd or not, an exception's too; so each binding is generalised,
   the explicit type variable scoped at its val (4.6) with it, and used at
   two types. ref is no conexp (tests/errors/err.ty_conexp-ref). *)
val x = (SOME : 'a list -> 'a list option) nil
val p = (x : int list option, x : bool list option)
val z = ((SOME : 'c list -> 'c list option) : 'c list -> 'c list option) nil
val y = (op :: : 'b list * 'b list list -> 'b list list) (nil, nil)
val a = case x of SOME l => 1 :: l | NONE => []
val b = case x of SOME l => "s" :: l | NONE => []
val q = (z : int list option, z : string list option, y : int list list, y : real list list)
exception E of int list
val e = (E : int list -> exn) [1, 2]
val n = case e of E l => length l | _ => 0
val w = (SOME : ('d -> 'd) -> ('d -> 'd) option) (fn v => v)
val three = case w of SOME f => f 3 | NONE => 0
val yes = case w of SOME f => f true | NONE => false
val () = print (Int.toString (length a + length b) ^ " " ^ Int.toString (length (#4 q)) ^ " " ^ Int.toString n ^ " "
                ^ Int.toString three ^ " " ^ Bool.toString yes ^ "\n")
