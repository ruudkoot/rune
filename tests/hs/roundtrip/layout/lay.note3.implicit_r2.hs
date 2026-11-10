-- rows: R2 deviation
module M where
data R = R { f :: Int }
g = let { x = do y } in x
h = R { f = do y }
