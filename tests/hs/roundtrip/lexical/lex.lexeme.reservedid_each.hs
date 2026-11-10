module M where
f = let x = case 1 of _ -> 2 in if True then do x else x
