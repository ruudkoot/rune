module M where
f :: Eq a => [a] -> a
f (x:_) = case [y | y@ ~z <- [x..]] of { [] -> x; _ -> (\w -> w) x }
