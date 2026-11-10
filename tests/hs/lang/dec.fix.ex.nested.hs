-- rows: dec.fix.ex.nestedown dec.fix.lambdabound R25
-- Report 4.4.2: a local operator with no fixity declaration is infixl 9 though a top-level one of its name has another; with
-- one of its own it has that; a lambda-bound operator is infixl 9.
module Main (main) where

infixr 6 +++

(+++) :: Int -> Int -> Int
a +++ b = a + b

main :: IO ()
main = do
  print (let a +++ b = a - b in 10 +++ 3 +++ 2 :: Int)
  print (let { infixr 6 +++; a +++ b = a - b } in 10 +++ 3 +++ 2 :: Int)
  print ((\(+) -> 1 + 2 * 3) (-) :: Int)
