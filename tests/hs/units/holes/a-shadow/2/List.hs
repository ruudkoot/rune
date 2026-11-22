-- The program's own List, which an import of List now names.
module List (sort) where

sort :: [Int] -> [Int]
sort = reverse
