-- Report 10: Num is not derivable.
module Main (main) where

data T = A deriving Num

main :: IO ()
main = return ()
