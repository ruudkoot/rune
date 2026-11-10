-- rows: der.show.record.chars der.show.record.prec der.show.record.neg der.show.record.opfield der.show.record.opcon der.show.record.empty der.show.infix.backtick der.show.prefix.opcon der.read.prec.range der.read.record.all der.read.record.prec R41 R87
-- Report 10.4, readings.md R87 (implementation-defined): derived Show and Read of records in Haskell 2010's form.
module Main (main) where

data R = C {f :: Int, g :: Int} deriving (Show, Read)
data S = S {h :: Int} deriving (Show, Read)
data O = O {(+++) :: Int} deriving Show
data P = (:+:) {pf :: Int} deriving Show
data E = D {} deriving Show
data B = Int `Bq` Int deriving Show
data Q = (:+) Int Int deriving Show

main :: IO ()
main = do
  putStrLn (show (C {f = 1, g = 2}))
  putStrLn (showsPrec 11 (S {h = 1}) "")
  putStrLn (show (S {h = -1}))
  putStrLn (show (O 1))
  putStrLn (show ((:+:) 1))
  putStrLn (show D)
  putStrLn (show (1 `Bq` 2))
  putStrLn (show ((:+) 1 2))
  print (length (readsPrec 11 "S {h = 1}" :: [(S, String)]), length (reads "C {f = 1}" :: [(R, String)]))
  print (h (read "S {h = 7}"), fmap h (read "Just (S {h = 8})" :: Maybe S))
