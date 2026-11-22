-- rows: R10
-- Report 3.4: prefix negation keeps the precedence of the Prelude's binary -, whatever the fixity of the - in scope:
-- under infixl 9 -, - 2 `div` 3 is still -(2 `div` 3), where 7 - 2 * 3 is (7 - 2) * 3.
module Main (main) where

import Prelude hiding ((-))

infixl 9 -

(-) :: Int -> Int -> Int
a - b = a + b

main :: IO ()
main = print (- 2 `div` 3 :: Int, 7 - 2 * 3)
