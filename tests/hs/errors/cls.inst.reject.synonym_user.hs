-- Report 4.3.2: the head's constructor is no synonym: not a user's.
module Main (main) where

type S = [Int]
class C a
instance C S

main :: IO ()
main = return ()
