functor BenchHartelComprDataFn (B : sig
  type expr
  type def
  type qual
  val var : string -> expr
  val cns : string -> expr
  val app : string * (unit -> expr list) -> expr
  val cmp : (unit -> expr) * (unit -> qual list) -> expr
  val letExpr : (unit -> def list) * (unit -> expr) -> expr
  val definition : string * string list * (unit -> expr) -> def
  val gen : int * string * (unit -> expr) -> qual
  val fil : (unit -> expr) -> qual
end) =
struct
  val program = [B.definition ("sqs",["xs"],fn()=>B.cmp (fn()=>B.app ("sq",fn()=>[B.var "x"]),fn()=>[B.gen (1,"x",fn()=>B.var "xs"),B.fil (fn()=>B.app ("odd",fn()=>[B.var "x"]))])),
    B.definition ("xys",["xs","ys"],fn()=>B.cmp (fn()=>B.app (",",fn()=>[B.var "x",B.var "y"]),fn()=>[B.gen (2,"x",fn()=>B.var "xs"),B.gen (3,"y",fn()=>B.var "ys")])),
    B.definition ("sq",["x"],fn()=>B.app ("*",fn()=>[B.var "x",B.var "x"])),
    B.definition ("odd",["x"],fn()=>B.app ("if",fn()=>[B.app ("=",fn()=>[B.app ("%",fn()=>[B.var "x",B.cns "1"]),B.cns "0"]),B.cns "true",B.cns "false"])),
    B.definition ("q",["c","d"],fn()=>B.letExpr (fn()=>[B.definition ("e",["z"],fn()=>B.app ("*",fn()=>[B.var "c",B.var "z"])),B.definition ("p",["a","b"],fn()=>B.letExpr (fn()=>[B.definition ("f",["x","y"],fn()=>B.app ("*",fn()=>[B.var "c",B.var "x"])),B.definition ("g",["y","z"],fn()=>B.app ("f",fn()=>[B.var "b",B.var "y"])),B.definition ("h",[],fn()=>B.app ("g",fn()=>[B.var "a",B.var "d"]))],fn()=>B.app ("f",fn()=>[B.app ("g",fn()=>[B.var "h",B.var "a"]),B.var "c"]))),B.definition ("q",[],fn()=>B.app ("e",fn()=>[B.app ("p",fn()=>[B.var "c",B.var "d"])]))],fn()=>B.app ("e",fn()=>[B.var "q"])))]
end
