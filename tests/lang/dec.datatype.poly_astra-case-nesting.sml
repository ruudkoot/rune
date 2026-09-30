val _ = print (Int.toString (case true of true => (case false of true => 0 | false => 42) | false => 0) ^ "\n")
val _ = print (Int.toString ((case true of true => fn x => x+2) 40) ^ "\n")
val _ = print (if true andalso case false of true => false | false => true then "yes\n" else "no\n")
