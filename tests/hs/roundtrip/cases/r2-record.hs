data R = R { f :: Int }
main = print (f (R { f = case 1 of y -> y }))
