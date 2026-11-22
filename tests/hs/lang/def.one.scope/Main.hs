-- rows: def.notexported mod.flatten.default
-- Report 4.3.4, 5: a default declaration holds in its module alone: M defaults to Double, Main, which imports M, to
-- Integer; one module could not do both.
module Main (main) where

import M

main :: IO ()
main = do
  putStrLn mshow
  print (2 ^ 70)
