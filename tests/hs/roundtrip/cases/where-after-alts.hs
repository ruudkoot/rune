f x = case x of
  1 -> y
  _ -> 2
  where y = 3
main = print (f 1)
