val () = print (str #"a" ^ str #"\n" ^ str #"\t" ^ str #"\"" ^ str #"\\" ^ str #"\065" ^ str #"\u0042" ^ str #"\^C" ^ "|\n")
val () = print (Int.toString (ord #"\^C") ^ " " ^ Int.toString (ord #"\255") ^ "\n")
