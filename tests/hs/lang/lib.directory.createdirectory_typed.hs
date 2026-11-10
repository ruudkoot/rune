-- rows: lib.directory.removedirectory lib.directory.removefile lib.directory.renamedirectory lib.directory.renamefile lib.directory.getdirectorycontents lib.directory.getcurrentdirectory lib.directory.setcurrentdirectory lib.directory.doesfileexist lib.directory.doesdirectoryexist lib.directory.getpermissions lib.directory.setpermissions lib.directory.getmodificationtime
-- Report 22: each function of Directory at its Report type, by a signature; running it does nothing.
module Main (main) where

import Directory
import Time (ClockTime)

createDirectory' :: FilePath -> IO ()
createDirectory' = createDirectory

removeDirectory' :: FilePath -> IO ()
removeDirectory' = removeDirectory

removeFile' :: FilePath -> IO ()
removeFile' = removeFile

renameDirectory' :: FilePath -> FilePath -> IO ()
renameDirectory' = renameDirectory

renameFile' :: FilePath -> FilePath -> IO ()
renameFile' = renameFile

getDirectoryContents' :: FilePath -> IO [FilePath]
getDirectoryContents' = getDirectoryContents

getCurrentDirectory' :: IO FilePath
getCurrentDirectory' = getCurrentDirectory

setCurrentDirectory' :: FilePath -> IO ()
setCurrentDirectory' = setCurrentDirectory

doesFileExist' :: FilePath -> IO Bool
doesFileExist' = doesFileExist

doesDirectoryExist' :: FilePath -> IO Bool
doesDirectoryExist' = doesDirectoryExist

getPermissions' :: FilePath -> IO Permissions
getPermissions' = getPermissions

setPermissions' :: FilePath -> Permissions -> IO ()
setPermissions' = setPermissions

getModificationTime' :: FilePath -> IO ClockTime
getModificationTime' = getModificationTime

main :: IO ()
main = putStrLn "typed"
