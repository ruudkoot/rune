-- Report 4.3.3: an explicit instance of a class also derived is a static error.
module Main (main) where

data T = A deriving Eq
instance Eq T where
  _ == _ = True

main :: IO ()
main = return ()
