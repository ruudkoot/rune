-- rows: dec.fix.table.dot dec.fix.table.caret dec.fix.table.caretcaret dec.fix.table.starstar dec.fix.table.star dec.fix.table.slash dec.fix.table.div dec.fix.table.mod dec.fix.table.rem dec.fix.table.quot dec.fix.table.plus dec.fix.table.minus dec.fix.table.colon dec.fix.table.plusplus dec.fix.table.andand dec.fix.table.oror dec.fix.table.thenm dec.fix.table.bindm dec.fix.table.bindr dec.fix.table.dollar dec.fix.table.dollarbang dec.fix.table.seq
-- Report 4.4.2, Table 4.1 as the erratum of July 2004 completes it, and chapter 8's infixr 1 =<<: each operator's
-- nesting shown by a value.
module Main (main) where

newtype S = S String deriving (Eq, Show)
instance Num S where
  S a + S b = S ("(" ++ a ++ "+" ++ b ++ ")")
  S a * S b = S ("(" ++ a ++ "*" ++ b ++ ")")
  negate (S a) = S ("-" ++ a)
  abs = id
  signum = id
  fromInteger n = S (show n)

main :: IO ()
main = do
  print ([[1, 2], [3, 4]] !! 1 !! 0 :: Int, (show . (+ 1) . (* 2)) (3 :: Int))
  print (2 ^ 3 ^ 2 :: Int, 2 ^^ 3 ^ 2 :: Double, 2 ** 3 ** 2 :: Double, 2 * 3 ^ 2 + 1 :: Int)
  print (8 / 2 / 2 :: Double, 8 `div` 2 `div` 2 :: Int, 17 `mod` 7 `mod` 2 :: Int, 17 `rem` 7 `rem` 2 :: Int, 64 `quot` 4 `quot` 2 :: Int)
  print (S "a" + S "b" + S "c", 1 - 2 - 3 :: Int, 1 : 2 : [] :: [Int], 1 : [2] ++ [3] :: [Int])
  print (False && undefined || True, True || undefined && undefined)
  print (Just (1 :: Int) >>= return . (+ 1) >>= return . (* 2), Just (1 :: Int) >> Just (2 :: Int) >> Just (3 :: Int))
  print ((return . (* 2)) =<< (return . (+ 1)) =<< Just (1 :: Int))
  print (negate $ abs $ (-3 :: Int), negate $! abs $! (-3 :: Int), (1 :: Int) `seq` (2 :: Int) `seq` (3 :: Int))
