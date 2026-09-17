fun make [text] true = text | make [text] false = text ^ "!" | make _ _ = "bad"
val saved = make [Int.toString 42]
val read = fn true => saved | false => saved
fun churn 0 = () | churn n = let val garbage = [Int.toString n, "!"] in churn (n - 1) end
val _ = churn 10000
val _ = print ((read true) false ^ "\n")
