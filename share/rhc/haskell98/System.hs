-- Module System, section 23 of the Haskell 98 Report.
-- The code of the online Revised Report of December 2002 with its published
-- errata applied: a modified version of the Report's code, which does not
-- define Haskell 98. LICENSE says what was changed; errata.tsv and
-- overlay.tsv list each change, and pristine/ holds the code as printed.

module System ( 
    ExitCode(ExitSuccess,ExitFailure),
    getArgs, getProgName, getEnv, system, exitWith, exitFailure
  ) where

data ExitCode = ExitSuccess | ExitFailure Int 
                deriving (Eq, Ord, Read, Show)

getArgs 		:: IO [String]
getProgName 		:: IO String
getEnv        		:: String -> IO String
system        		:: String -> IO ExitCode
exitWith   		:: ExitCode -> IO a
exitFailure		:: IO a
