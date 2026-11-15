-- Left to right, top to bottom (3.17.2): a clause forces its columns in
-- order, up to the first that fails, and no further. Sestoft's trees
-- (D34's B) must force no column the Report's order leaves alone, and
-- every one it forces.
-- sestoft: as A
module Main where

data C = P | Q

-- a refutable column after one whose value is bottom
f :: Bool -> Bool -> Int
f _ True = 1
f True False = 2
f False False = 3

-- two columns, the clauses testing them in either order
h :: C -> C -> Int
h _ P = 1
h P Q = 2
h Q Q = 3

-- the first column refutable in the first clause: the Report forces it
g :: Bool -> Bool -> Int
g True True = 1
g _ False = 2
g _ _ = 3

main :: IO ()
main = do
  print (f undefined True)
  print (h undefined P)
  print (h Q Q)
  print (g True False)
  print (g undefined False)
