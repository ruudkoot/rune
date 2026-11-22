-- Report 9.5: inst -> ( tyvar1 , ... , tyvark ), tyvars distinct: not (a, a).
module Main (main) where

class C a
instance C (a, a)

main :: IO ()
main = return ()
