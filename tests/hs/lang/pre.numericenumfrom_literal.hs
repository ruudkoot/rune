-- rows: pre.numericenumfromthen pre.numericenumfromto pre.numericenumfromthento
-- Report 8: Enum Float and Enum Double by numericEnumFrom and its kin, against the Report's own definitions copied under
-- new names, on steps a binary fraction holds exactly (readings.md R39).
module Main (main) where

numericEnumFrom' :: (Fractional a) => a -> [a]
numericEnumFrom' n = iterate (+ 1) n

numericEnumFromThen' :: (Fractional a) => a -> a -> [a]
numericEnumFromThen' n m = iterate (+ (m - n)) n

numericEnumFromTo' :: (Fractional a, Ord a) => a -> a -> [a]
numericEnumFromTo' n m = takeWhile (<= m + 1 / 2) (numericEnumFrom' n)

numericEnumFromThenTo' :: (Fractional a, Ord a) => a -> a -> a -> [a]
numericEnumFromThenTo' n n' m = takeWhile p (numericEnumFromThen' n n')
  where p | n' >= n = (<= m + (n' - n) / 2)
          | otherwise = (>= m + (n' - n) / 2)

main :: IO ()
main = do
  print (take 4 [1.5 ..] == take 4 (numericEnumFrom' (1.5 :: Double)), take 4 [1.0, 1.25 ..] == take 4 (numericEnumFromThen' 1.0 (1.25 :: Double)))
  print ([1.0 .. 2.5] == numericEnumFromTo' 1.0 (2.5 :: Double), [1.0 .. 0.5] == numericEnumFromTo' 1.0 (0.5 :: Double))
  print ([3.0, 2.0 .. 0.5] == numericEnumFromThenTo' 3.0 2.0 (0.5 :: Double), [1.0, 1.5 .. 3.0] == numericEnumFromThenTo' 1.0 1.5 (3.0 :: Float))
  print (take 2 (numericEnumFrom' (undefined :: Double)) `seq` (), length (take 3 (numericEnumFromThen' 1 (undefined :: Double))))
