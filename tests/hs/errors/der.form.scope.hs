-- Report 10: only the Prelude's derivable classes can be derived: a user class cannot.
module Main (main) where

class C a

data T = A deriving C

main :: IO ()
main = return ()
