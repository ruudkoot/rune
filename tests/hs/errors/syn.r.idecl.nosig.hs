-- Report 9.5: idecl -> (funlhs | var) rhs | (empty): no signature in an instance body.
module Main (main) where

class C a where
  m :: a -> Int
instance C Bool where
  m :: Bool -> Int
  m _ = 0

main :: IO ()
main = return ()
