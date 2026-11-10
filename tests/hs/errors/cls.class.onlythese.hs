-- Report 4.3.1: no other declarations are permitted in cdecls: no data declaration in a class.
module Main (main) where

class C a where
  data T = T

main :: IO ()
main = return ()
