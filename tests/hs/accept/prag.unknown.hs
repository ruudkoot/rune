-- rows: prag.lexical prag.noinline prag.specialize
-- Report 11: pragmas are comments to the language: an unknown one compiles wherever it stands, raises no layout token,
-- nests with comments; NOINLINE and the Report's SPECIALIZE example compile.
module Main (main) where

{-# FROB x #-}
factorial :: Num a => a -> a
factorial n = if n == 0 then 1 else n * factorial (n - 1)
{-# SPECIALIZE factorial :: Int -> Int, Integer -> Integer #-}

f :: Int -> Int
{-# NOINLINE f #-}
f x = let y = x
          {-# FROB y #-}
          z = 2 {- {-# FROB #-} -}
      in y + z

main :: IO ()
main = print (f 1, factorial (5 :: Int)) {-# FROB #-}
