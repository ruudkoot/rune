module Stack (push, empty) where

push :: Int -> [Int] -> [Int]
push = (:)

empty :: [Int]
empty = []
