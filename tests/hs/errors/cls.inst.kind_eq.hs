-- Report 4.3.2: the class and the type have one kind: not Eq Maybe.
module Main (main) where

instance Eq Maybe

main :: IO ()
main = return ()
