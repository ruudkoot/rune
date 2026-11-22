-- Report 4.2.2: mutually recursive synonyms are not allowed.
module Main (main) where

type Rec a = [Circ a]
type Circ a = [Rec a]

main :: IO ()
main = return ()
