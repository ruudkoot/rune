-- Report 3.15.2: K {} is refused where K has a strict field.
module Main (main) where

data T = F !Int

v :: T
v = F {}

main :: IO ()
main = return ()
