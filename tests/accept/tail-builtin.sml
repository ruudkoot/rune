fun emit text = print text
fun convert n = Int.toString n
val _ = emit (convert 42 ^ "\n")
