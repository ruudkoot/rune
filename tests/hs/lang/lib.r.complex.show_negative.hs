-- rows: R42 R49
-- Report 13.1, 10.4: Complex derives Show at infix 6, and a negative component is parenthesised above precedence 6, as
-- showSigned showFloat does (R42: 10.4's text over chapter 8's code), so that show reads back.
module Main (main) where

import Complex

main :: IO ()
main = do
  putStrLn (show ((-1.5) :+ (-2) :: Complex Double))
  putStrLn (show (1.5 :+ (-2) :: Complex Double))
  putStrLn (showsPrec 6 ((-1.5) :+ 2 :: Complex Double) "")
  putStrLn (showsPrec 7 ((-1.5) :+ 2 :: Complex Double) "")
  print (Just ((-0.5) :+ 1 :: Complex Float), [0 :+ (-1) :: Complex Double])
  print (read (show ((-1.5) :+ (-2) :: Complex Double)) == ((-1.5) :+ (-2) :: Complex Double), read "(-1.5) :+ (-2.0)" :: Complex Double)
