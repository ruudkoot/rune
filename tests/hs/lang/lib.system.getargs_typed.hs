-- rows: lib.system.getprogname lib.system.getenv lib.system.system lib.system.exitwith lib.system.exitfailure
-- Report 23: each function of System at its Report type, by a signature; running it does nothing.
module Main (main) where

import System

getArgs' :: IO [String]
getArgs' = getArgs

getProgName' :: IO String
getProgName' = getProgName

getEnv' :: String -> IO String
getEnv' = getEnv

system' :: String -> IO ExitCode
system' = system

exitWith' :: ExitCode -> IO a
exitWith' = exitWith

exitFailure' :: IO a
exitFailure' = exitFailure

main :: IO ()
main = putStrLn "typed"
