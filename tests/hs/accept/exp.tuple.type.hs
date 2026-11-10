-- Report 3.8: (e1, ..., ek) has type (t1, ..., tk).
module Main (main) where

t :: (Int, Char)
t = (1 :: Int, 'a') :: (Int, Char)

main :: IO ()
main = return ()
