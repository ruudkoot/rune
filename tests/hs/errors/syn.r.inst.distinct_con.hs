-- Report 9.5: inst -> ( gtycon tyvar1 ... tyvark ), tyvars distinct: not T a a.
module Main (main) where

data T a b = T
class C a
instance C (T a a)

main :: IO ()
main = return ()
