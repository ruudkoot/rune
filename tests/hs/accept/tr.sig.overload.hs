-- Report 3.16: e :: t with a context: (1 :: Num a => a) at Int.
module Main (main) where

x :: Int
x = (1 :: Num a => a)

main :: IO ()
main = return ()
