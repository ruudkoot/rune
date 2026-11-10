-- Report 9.3, Note 1: "A nested context must be further indented than the enclosing context (n>m)": the Report's
-- example, whose p z = z stands left of h y, is refused.
module Main (main) where

f :: Int -> Int
f x = let
         h y = let
  p z = z
               in p
      in h x

main :: IO ()
main = return ()
