-- Report 12.1: show of a ratio at precedence 7, its parts at 8: parenthesised above 7, a negative numerator in
-- parentheses.
module Main (main) where

import Ratio

main :: IO ()
main = do
  putStrLn (showsPrec 8 (1 % 2 :: Rational) "")
  putStrLn (showsPrec 7 (1 % 2 :: Rational) "")
  putStrLn (show ((-1) % 2 :: Rational))
  print (Just (3 % 4 :: Ratio Int))
  print [1 % 3, 2 % 5 :: Rational]
