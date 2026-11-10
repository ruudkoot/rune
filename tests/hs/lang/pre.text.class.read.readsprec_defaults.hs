-- rows: pre.text.class.read.readlist pre.text.class.show.showsprec pre.text.class.show.show pre.text.class.show.showlist
-- Report 8.2: Read's readList defaults to a bracketed list of readsPrec's, Show's show and showsPrec to each other and
-- showList to a bracketed list of shows; every method defined overrides its default.
module Main (main) where

data A = A deriving Show
instance Read A where
  readsPrec _ s = [(A, t) | ("A", t) <- lex s]

data B = B deriving Show
instance Read B where
  readsPrec _ s = [(B, t) | ("B", t) <- lex s]
  readList _ = [([B, B, B], "")]

data S1 = S1
instance Show S1 where
  show _ = "s1"

data S2 = S2
instance Show S2 where
  showsPrec d _ = showString ("s2@" ++ show d)

data S3 = S3
instance Show S3 where
  show _ = "s3"
  showsPrec _ _ = showString "p3"
  showList _ = showString "l3"

main :: IO ()
main = do
  print (read " [A, A] " :: [A], read "A" :: A, read "[]" :: [B])
  putStrLn (show S1 ++ " " ++ showsPrec 5 S1 "" ++ " " ++ show [S1, S1])
  putStrLn (show S2 ++ " " ++ showsPrec 7 S2 "" ++ " " ++ show [S2])
  putStrLn (show S3 ++ " " ++ showsPrec 1 S3 "" ++ " " ++ show [S3])
