module M where
class C a where
  m :: a
instance C Int where
  m = 0
f x = case x of
    1 -> y
    _ -> z
  where y = 1
        z = let w = 2 in w
g = do
  h
  h
