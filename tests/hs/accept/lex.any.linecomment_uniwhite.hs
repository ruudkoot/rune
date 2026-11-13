-- rows: lay.col.vt R4 deviation
-- Report 2.2 and 9.3 (R4, the owner's call of 2026-11-10): any is graphic, space or tab, so a line comment may hold no
-- vertical tab and no other uniWhite, though a nested comment may; rhc accepts them in a line comment, a deviation from
-- the grammar taken literally (tests/hs/deviations.tsv). And 9.3 does not say how far a vertical tab moves the column:
-- rhc counts it one, so y below, after a vertical tab and three spaces, is at x's column 5 and in its block (at 0 or
-- at 8 it would end the block or continue x's binding, and the module would not parse).
module Main (main) where

-- a vertical tab , a no-break space  , an em space   and an ideographic space 　

f :: Int
f = x + y
  where
    x = 1
   y = 2

main :: IO ()
main = print f
