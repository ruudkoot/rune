-- rows: tr.dec.pat.fallthrough
-- Report 4.4.3.2: x | False = 1 is unused and the program prints; used, it is an error, not a fall-through.
module Main (main) where

x :: Int
x | False = 1

main :: IO ()
main = do
  putStrLn "unused"
  print x
