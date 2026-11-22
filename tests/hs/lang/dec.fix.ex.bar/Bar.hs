module Bar (op) where

infixr 7 `op`

op :: Int -> Int -> Int
op a b = a - b
