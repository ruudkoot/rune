-- The reads a unit's compile makes: each import item (H1), each name looked up, a local one too (H1), the instance
-- the module declares looked up first and absent (H2), all of M's exports for `module M` (H7), and the Prelude's
-- names that do-notation's translation asks for (H9).
module All (module M, f, T) where

import M (g, Q(..))

data T = T Int

instance Show T where
  show (T n) = show n

f :: Int -> IO ()
f n = do
  print (g n)
  print (T n)
