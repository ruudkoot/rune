module M where
f x = case x of
  n | n > 0
    -> 1
    | otherwise
    -> 2
