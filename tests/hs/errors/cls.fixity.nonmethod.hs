-- Report 4.3.1: cdecls hold a fixity declaration of their methods alone.
module Main (main) where

class C a where
  infixl 6 +++
  m :: a -> a

(+++) :: Int -> Int -> Int
a +++ b = a

main :: IO ()
main = return ()
