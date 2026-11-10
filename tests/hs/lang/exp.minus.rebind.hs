-- rows: exp.neg.prelude exp.neg.nolink
-- Report 3.4: the binary - may be rebound by the module system; unary - is always the Prelude's negate, with no link to
-- the local -.
module Main (main) where

import Prelude hiding ((-))

infixl 6 -

(-) :: String -> String -> String
a - b = a ++ b

main :: IO ()
main = do
  putStrLn ("ab" - "cd")
  print (- (3 :: Int))
  let x = 4 :: Int
  print (-x)
