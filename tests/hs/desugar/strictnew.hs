-- A strict field of a newtype's type forces the newtype's representation (4.2.1, 4.2.3): a constructor applied to
-- a newtype of bottom is bottom, saturated or through the constructor as a function, and a newtype of a newtype the
-- same (jhc's StrictNewtype, through E8's corpus).
module Main (main) where

newtype TID = TID Int deriving Show
newtype Wrap = Wrap TID deriving Show

data Foo = Foo !TID Char !Int deriving Show
data Bar = Bar !Wrap

isBar :: Bar -> Bool
isBar (Bar _) = True

main :: IO ()
main = do
  print (Foo (TID 3) 'x' 4)
  let Foo t c n = Foo (TID 5) 'y' 6
  print (t, c, n)
  print (map (Foo (TID 7) 'w') [1, 2])
  print (isBar (Bar (Wrap (TID 1))))
  print (case Bar (Wrap (TID undefined)) of Bar _ -> True)
