-- Report 4.3.2: an instance binds only the class's methods: not another variable.
module Main (main) where

class C a where
  m :: a -> Int
instance C Bool where
  m _ = 0
  other _ = 1

main :: IO ()
main = return ()
