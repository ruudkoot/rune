(* Printers (docs/plans/quickcheck.md, D4): Standard ML that reads back. *)

(* Implements: SHOW *)
structure Show :> SHOW =
struct
  type 'a show = 'a -> string

  fun parens (s : string) : string =
    if CharVector.exists (fn c => c = #" ") s andalso not (String.isPrefix "(" s) andalso not (String.isPrefix "[" s)
       andalso not (String.isPrefix "\"" s)
    then "(" ^ s ^ ")"
    else s

  val int : int show = Int.toString
  val word : word show = fn w => "0wx" ^ Word.fmt StringCvt.HEX w
  val word64 : Word64.word show = fn w => "0wx" ^ Word64.fmt StringCvt.HEX w
  val char : char show = fn c => "#\"" ^ Char.toString c ^ "\""
  val string : string show = fn s => "\"" ^ String.toString s ^ "\""
  val real : real show =
    fn x =>
      if Real.isNan x then "0.0 / 0.0"
      else if Real.isFinite x then Real.fmt (StringCvt.GEN (SOME 17)) x
      else if x > 0.0 then "Real.posInf"
      else "Real.negInf"
  val bool : bool show = Bool.toString
  val unit : unit show = fn () => "()"
  val order : order show = fn LESS => "LESS" | EQUAL => "EQUAL" | GREATER => "GREATER"
  fun option (s : 'a show) : 'a option show = fn NONE => "NONE" | SOME x => "SOME " ^ parens (s x)
  fun list (s : 'a show) : 'a list show = fn l => "[" ^ String.concatWith ", " (List.map s l) ^ "]"
  fun vector (s : 'a show) : 'a vector show = fn v => "Vector.fromList " ^ list s (Vector.foldr (op ::) [] v)
  fun array (s : 'a show) : 'a array show = fn v => "Array.fromList " ^ list s (Array.foldr (op ::) [] v)
  fun pair (s : 'a show, t : 'b show) : ('a * 'b) show = fn (x, y) => "(" ^ s x ^ ", " ^ t y ^ ")"
  fun triple (s : 'a show, t : 'b show, u : 'c show) : ('a * 'b * 'c) show =
    fn (x, y, z) => "(" ^ s x ^ ", " ^ t y ^ ", " ^ u z ^ ")"
end
