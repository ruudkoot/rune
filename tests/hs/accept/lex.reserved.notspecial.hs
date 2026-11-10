-- Report 2.4: nothing but reservedid is reserved: forall, foreign, mdo, proc, rec, family, role, as, hiding and
-- qualified are varids.
module Main (main) where

main :: IO ()
main = print [forall, foreign, mdo, proc, rec, family, role, as, hiding, qualified]
  where
    forall = 1 :: Int
    foreign = 2
    mdo = 3
    proc = 4
    rec = 5
    family = 6
    role = 7
    as = 8
    hiding = 9
    qualified = 10
