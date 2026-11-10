-- rows: lib.system.export.getargs lib.system.export.getprogname lib.system.export.getenv lib.system.export.system lib.system.export.exitwith lib.system.export.exitfailure
-- Report 23: module System exports each of these: an explicit import of every one compiles, and each name is used.
module Main (main) where

import System (ExitCode(ExitSuccess,ExitFailure), getArgs, getProgName, getEnv, system, exitWith, exitFailure)

t0 :: ExitCode -> ()
t0 _ = ()
s0_0 _ = ExitSuccess
s0_1 _ = ExitFailure

v1 _ = getArgs

v2 _ = getProgName

v3 _ = getEnv

v4 _ = system

v5 _ = exitWith

v6 _ = exitFailure

main :: IO ()
main = return ()
