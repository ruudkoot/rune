(* Exact typed-ID/embedded-rule graph extracted from the pinned Haskell source. *)
structure BenchBoyerIds =
struct
  val names = Vector.fromList ["A","B","C","D","X","Y","Z","U","W","ADD1","AND","IF","TRUE","FALSE","APPEND","CONS","CONSP","DIFFERENCE","ZERO","PLUS","REMAINDER","ONE","TIMES","QUOTIENT","TWO","ZEROP","EQUAL","NOT","LESSP","OR","DIVIDES","EVEN","ODD","SUB1","EXP","F","FOUR","GCD","GREATEREQP","GREATERP","IFF","IMPLIES","LENGTH","REVERSE","LESSEQP","LISTP","NILP","NIL","MEMBER","NLISTP"]
  val trueId = 12
  val falseId = 13
  val ifId = 11
  val xId = 4
end
