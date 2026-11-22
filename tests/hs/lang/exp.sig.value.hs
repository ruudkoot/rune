-- rows: tr.sig
-- Report 3.16: e :: t has the value of e, at t.
module Main (main) where

main :: IO ()
main = do
  print (1 :: Int, (2 :: Double) / 4, let x = (3 :: Integer) in x)
  print (let e :: Int
             e = 5
         in e)
