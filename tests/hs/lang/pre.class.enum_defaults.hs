-- rows: pre.class.enum pre.class.enum.succ pre.class.enum.pred pre.class.enum.toenum pre.class.enum.fromenum pre.class.enum.enumfrom pre.class.enum.enumfromthen pre.class.enum.enumfromto pre.class.enum.enumfromthento
-- Report 8: class Enum's defaults from toEnum and fromEnum: succ, pred and the four sequences through Int's; every method
-- defined overrides its default.
module Main (main) where

data A = A Int deriving Show
instance Enum A where
  toEnum = A
  fromEnum (A n) = n

data B = B Int deriving Show
instance Enum B where
  toEnum = B
  fromEnum (B n) = n
  succ _ = B 100
  pred _ = B (-100)
  enumFrom _ = [B 1]
  enumFromThen _ _ = [B 2]
  enumFromTo _ _ = [B 3]
  enumFromThenTo _ _ _ = [B 4]

main :: IO ()
main = do
  print (succ (A 1), pred (A 1), toEnum 5 :: A, fromEnum (A 7))
  print (take 3 [A 3 ..], take 3 [A 1, A 3 ..], [A 1 .. A 3], [A 1, A 3 .. A 7])
  print (succ (B 1), pred (B 1), [B 0 ..], [B 0, B 1 ..])
  print ([B 0 .. B 9], [B 0, B 1 .. B 9])
