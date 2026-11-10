(* The constants of the intermediate representations, each by its kind
   (docs/ir.md): what Lambda, Mid, Low and the code they make hold. *)
structure Literal =
struct
  datatype const =
      CInt of IntInf.int
    | CWord of IntInf.int
    | CInt64 of IntInf.int                (* an Int64.int: 64 bits where int is the VM's 63 *)
    | CWord64 of IntInf.int               (* a Word64.word *)
    | CReal of string                     (* SML literal text *)
    | CString of string
    | CChar of int

  fun toString c =
    case c of
      CInt i => IntInf.toString i
    | CWord w => "0w" ^ IntInf.toString w
    | CInt64 i => IntInf.toString i
    | CWord64 w => "0w" ^ IntInf.toString w
    | CReal r => r
    | CString s => "\"" ^ String.toString s ^ "\""
    | CChar c => "#\"" ^ Char.toString (Char.chr c) ^ "\""
end
