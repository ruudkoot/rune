module M where
f = do { x <- g
       ; case x of
           1 -> h
           _ -> h
       }
g = let { y = do
            h
            h
        } in y
