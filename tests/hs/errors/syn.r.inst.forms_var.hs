-- Report 9.5: inst has five forms, none a type variable alone.
module Main (main) where

class C a
instance C a

main :: IO ()
main = return ()
