-- Report 3.15: exp.field.indep_ab with its fields declared in the other order: the same output.
module Main (main) where

data T = T { b :: String, a :: Int }

main :: IO ()
main = do
  let t = T { b = "x", a = 1 }
  print (a t, b t)
  let u = t { a = 2 }
  print (a u, b u)
  print (case u of T { b = s } -> s)
