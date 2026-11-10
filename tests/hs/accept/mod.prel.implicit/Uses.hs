module Uses (u) where

u :: [Int]
u = map (+ 1) (Prelude.map (+ 1) [1])
