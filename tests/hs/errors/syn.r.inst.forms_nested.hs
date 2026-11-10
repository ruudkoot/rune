-- Report 9.5: inst -> [ tyvar ]: not [[a]].
module Main (main) where

class C a
instance C [[a]]

main :: IO ()
main = return ()
