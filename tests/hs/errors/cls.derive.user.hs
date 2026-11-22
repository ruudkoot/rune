-- Report 4.3.3, 10: a class of the program is not derivable.
module Main (main) where

class C a
data T = A deriving C

main :: IO ()
main = return ()
