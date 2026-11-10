-- A program that exits with a status, which its .exitcode gives
-- (tests/runner/hslang.sml).
import System

main :: IO ()
main = do putStrLn "leaving"
          exitWith (ExitFailure 3)
