-- Report 3.15: fields construct, select and update independently of the declaration's order; exp.field.indep_ba
-- is this program with its fields declared in the other order, and prints the same.
module Main (main) where

data T = T { a :: Int, b :: String }

main :: IO ()
main = do
  let t = T { b = "x", a = 1 }
  print (a t, b t)
  let u = t { a = 2 }
  print (a u, b u)
  print (case u of T { b = s } -> s)
