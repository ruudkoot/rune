-- The Report's 20 modules compiled whole (the haskell98 roadmap's M18 done-when: the 20 modules compile): each
-- imported and a name of each used, so that rhc checks, desugars and compiles every module's code (hs/library/compile).
module Main (main) where

import qualified Array
import qualified CPUTime
import qualified Char
import qualified Complex
import qualified Directory
import qualified IO
import qualified Ix
import qualified List
import qualified Locale
import qualified Maybe
import qualified Monad
import qualified Numeric
import qualified Random
import qualified Ratio
import qualified System
import qualified Time

main :: IO ()
main = do
  print (Array.bounds (Array.listArray (0, 2 :: Int) "abc"), Char.toUpper 'x', Complex.realPart (1 Complex.:+ 2 :: Complex.Complex Double))
  print (Ix.inRange (1, 3 :: Int) 2, List.sort [3, 1, 2 :: Int], Maybe.fromMaybe 0 (Nothing :: Maybe Int))
  print (Monad.join [[1 :: Int], [2]], Numeric.showHex (255 :: Int) "", Ratio.numerator (3 Ratio.% 6 :: Rational))
  print (Locale.dateFmt Locale.defaultTimeLocale, fst (Random.randomR (1, 1 :: Int) (Random.mkStdGen 3)))
  IO.hPutStrLn IO.stderr "to stderr"
  e <- Directory.doesFileExist "no-such-file"
  t <- CPUTime.getCPUTime
  c <- Time.getClockTime
  n <- System.getProgName
  print (e, t >= 0, Time.ctYear (Time.toUTCTime c) > 2000, not (null n))
  System.exitWith (System.ExitFailure 3)
