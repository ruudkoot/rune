fun f true = fn true => 1 | false => 2 | f false = (fn _ => 3)
