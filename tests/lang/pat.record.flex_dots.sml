type person = {name : string, age : int, email : string}
fun name ({name, ...} : person) = name
fun older ({age, ...} : person, n) = age > n
val p = {name = "Ada", age = 36, email = "ada@example.com"}
val () = print (name p ^ Bool.toString (older (p, 30)) ^ "\n")
val {email, ...} = p
val () = print (email ^ "\n")
fun agePlus ({age = a as _, ...} : person) = a + 1
val () = print (Int.toString (agePlus p) ^ "\n")
