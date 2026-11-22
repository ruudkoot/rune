-- Report 4.3.2: the head's constructor is no synonym: not String.
module Main (main) where

class C a
instance C String

main :: IO ()
main = return ()
