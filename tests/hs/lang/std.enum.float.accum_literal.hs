-- rows: std.enum.float.count R39
-- Report 6.3.4, 8, readings.md R39 (D38: the text decides, and the text is chapter 8's code): [0,0.1..1] at Double is
-- the iterated sum of the code, each element exactly the literal definition's, eleven of them.
module Main (main) where

numericEnumFromThen' :: (Fractional a) => a -> a -> [a]
numericEnumFromThen' n m = iterate (+ (m - n)) n

numericEnumFromThenTo' :: (Fractional a, Ord a) => a -> a -> a -> [a]
numericEnumFromThenTo' n n' m = takeWhile p (numericEnumFromThen' n n')
  where p | n' >= n = (<= m + (n' - n) / 2)
          | otherwise = (>= m + (n' - n) / 2)

main :: IO ()
main = do
  print ([0, 0.1 .. 1] == numericEnumFromThenTo' 0 0.1 (1 :: Double))
  print (length ([0, 0.1 .. 1] :: [Double]))
  print (and (zipWith (==) [0, 0.1 .. 1] (numericEnumFromThen' 0 (0.1 :: Double))))
