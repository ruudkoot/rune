-- Records (3.15): construction by field, a field left out undefined, an update of one or several fields, one that
-- changes a type parameter only the updated field has, selection, and a pattern of fields in its own order.
module Main (main) where

data P = P { px :: Int, py :: Int } | Q { px :: Int, pz :: String }

data T a = T { label :: a, count :: Int }

norm :: P -> Int
norm p = px p + (case p of P { py = y } -> y; Q {} -> 0)

relabel :: T a -> T String
relabel t = t { label = "new" }

fields :: P -> String
fields Q { pz = z, px = x } = z ++ show x
fields P {} = "p"

main :: IO ()
main = do
  print (norm (P { px = 1, py = 2 }))
  print (norm (Q { pz = "q", px = 5 }))
  print (px (P { px = 7 }))
  print (py ((P 1 2) { py = 20 }))
  print (px ((Q 3 "z") { px = 30, pz = "w" }))
  putStrLn (label (relabel (T { label = (1 :: Int), count = 4 })))
  print (count (relabel (T 'c' 9)))
  putStrLn (fields (Q 6 "six"))
  putStrLn (fields (P 1 1))
