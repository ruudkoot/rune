-- Report 4.3.2: a method's declaration is a variable or a function definition: not (a, b) = ...
module Main (main) where

class C a where
  m, n :: a -> Int
instance C Bool where
  (m, n) = (const 0, const 1)

main :: IO ()
main = return ()
