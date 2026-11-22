-- rows: pat.order R16
-- Report 3.17.3 (b): an alternative with no guards is one guarded by True; 3.17.2: matching goes left to right, outside in.
module Main (main) where

f :: (Bool, Bool) -> Int
f (True, _) = 1
f (_, True) = 2
f _ = 3

g :: (Bool, Bool) -> Int
g p = case p of { (True, _) | True -> 1; (_, True) | True -> 2; _ | True -> 3 }

main :: IO ()
main = do
  print (map f [(True, undefined), (False, True), (False, False)])
  print (map g [(True, undefined), (False, True), (False, False)])
  print (case (Just (1 :: Int), undefined :: Int) of { (Nothing, 0) -> 1; _ -> 2 :: Int })
