-- rows: tr.paren exp.tuple.one
-- Report 3.9: (e) is e, in fixity resolution too, and no tuple of one.
module Main (main) where

main :: IO ()
main = do
  print ((1 + 2) * 3, 1 + 2 * 3, (5))
  print ((((7))) == 7)
