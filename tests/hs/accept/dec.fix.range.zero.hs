-- rows: dec.fix.where
-- Report 4.4.2: precedences 0 and 9 are in range, and a fixity declaration stands wherever a signature may: at the top, in
-- a let, in a where and in a class.
module Main (main) where

infixl 0 +++
infixr 9 -+-
(+++), (-+-) :: Int -> Int -> Int
a +++ b = a + b
a -+- b = a - b

class C a where
  infix 4 ===
  (===) :: a -> a -> Bool

instance C Int where
  a === b = a == b

main :: IO ()
main = print (1 +++ 2 -+- 3, let { infixl 5 *** ; a *** b = a * (b :: Int) } in 2 *** 3, w, (1 :: Int) === 1)
  where
    infixr 5 ##
    a ## b = a - b
    w = 10 ## 3 ## 2 :: Int
