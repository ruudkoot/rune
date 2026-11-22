-- rows: std.enum.conv std.enum.bounded.from std.enum.bounded.then std.enum.inst.unit std.enum.inst.bool std.enum.inst.ordering std.enum.inst.char der.enum.unit std.enum.num.succ std.enum.num.conv std.enum.num.float.digits R7
-- Report 6.3.4: succ and pred, toEnum and fromEnum; at a bounded type enumFrom and enumFromThen stop at the bound; the
-- Report's examples [LT ..] and ['a' ..] at Char; at numeric types succ adds 1 and fromEnum truncates.
module Main (main) where

data C = Red | Green | Blue deriving (Show, Enum, Bounded)

main :: IO ()
main = do
  print (succ Red, pred Blue, toEnum (fromEnum Green) :: C, [Red ..])
  print ([True ..], [False, True ..], [True, False ..], last ['a' ..] == maxBound)
  print ([() ..], [False ..], [LT ..], take 3 ['a' ..])
  print (succ (1 :: Int), succ (1.5 :: Double), pred (10 :: Integer), fromEnum (2.5 :: Double), fromEnum (-2.5 :: Float))
  print (toEnum 3 :: Double, toEnum 65 :: Char)
