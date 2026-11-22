-- rows: R24
-- Report 4.2.1 (R24; the lead's ruling 49 moves the row from E9's test none to a run): a constructor's strictness
-- flags are forced by the translation (\x1 ... xn -> ((K' $!! x1) $!! x2) ... $!! xn), so the last flagged argument
-- first: of two bottoms, the second's error is the one reported, which only standard error shows (3.1: all bottoms
-- are one denotation), here by .stderr-head.
module Main (main) where

data T = T !Int !Int

main :: IO ()
main = case T (error "the first field") (error "the second field") of
         T _ _ -> putStrLn "unreached"
