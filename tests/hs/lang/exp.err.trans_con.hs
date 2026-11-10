-- rows: exp.field.con.missing
-- Report 3.1, 3.15.2: a field left out of a construction is undefined: unused it does nothing, demanded it terminates.
module Main (main) where

data T = C1 {f1, f2 :: Int}

main :: IO ()
main = do
  let x = C1 {f1 = 3}
  print (f1 x)
  print (f2 x)
