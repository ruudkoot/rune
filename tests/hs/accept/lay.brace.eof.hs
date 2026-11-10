-- rows: lay.l.6.eof lay.l.13 lay.note6.pending
-- Report 9.3: "If there is no next lexeme ... {0} is inserted"; {0} falls to equation 6 and gives {}, and at the end of
-- the input every pending context closes (equation 13, Note 6): this file ends in a where, inside two others.
module Main (main) where

main :: IO ()
main = print f
  where
    f = g
      where
        g = 1 :: Int where