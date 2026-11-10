module Queue (module Stack, enqueue, dequeue) where

import Stack

enqueue :: Int -> [Int]
enqueue x = push x empty

dequeue :: [Int] -> [Int]
dequeue = drop 1
