structure A = Measure (struct val start = 12 end)
structure B = Twice (struct val start = 3 end)
structure C = Measure (struct val start = 0 end)
val () = print (Int.toString A.total ^ " " ^ A.describe () ^ " " ^ Int.toString B.both ^ " "
                ^ C.describe () ^ " " ^ Bool.toString A.big ^ " " ^ Int.toString Shape.unrelated ^ "\n")
