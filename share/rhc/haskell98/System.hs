-- Module System, section 23 of the Haskell 98 Report.
-- The code of the online Revised Report of December 2002, with its published
-- errata and rhc's overlay applied: a modified version of the Report's code,
-- which does not define Haskell 98. LICENSE says what was changed; errata.tsv
-- and overlay.tsv list each change, and pristine/ holds the code as printed.

module System ( 
    ExitCode(ExitSuccess,ExitFailure),
    getArgs, getProgName, getEnv, system, exitWith, exitFailure
  ) where

import PreludeBuiltin                   -- the system's calls (rhc's)

data ExitCode = ExitSuccess | ExitFailure Int 
                deriving (Eq, Ord, Read, Show)

getArgs 		:: IO [String]
getArgs                 =  command_arg_count >>= \n ->
                           mapM (\i -> command_arg i >>= return . primUnpackStr) [0 .. n - 1]
getProgName 		:: IO String
getProgName             =  command_name >>= \s -> return (base (primUnpackStr s))
  where base f = case break (== '/') f of
                   (b, [])     -> b
                   (_, _:rest) -> base rest
getEnv        		:: String -> IO String
getEnv v                =  os_has_env (primPackStr v) >>= \b ->
                           if b then os_getenv (primPackStr v) >>= return . primUnpackStr
                           else ioError (IOError DoesNotExist ("getEnv: " ++ v ++ ": no such variable") Nothing Nothing)
system        		:: String -> IO ExitCode
system c                =  os_system (primPackStr c) >>= \n ->
                           if n < 0 then sys_errno >>= primFailWith ("system: " ++ c) Nothing Nothing
                           else return (if n == 0 then ExitSuccess else ExitFailure n)
exitWith   		:: ExitCode -> IO a
exitWith ExitSuccess    =  primExit 0
exitWith (ExitFailure n) = primExit n
exitFailure		:: IO a
exitFailure             =  exitWith (ExitFailure 1)   -- exitfail is 1 (23)
