-- rows: lib.directory.export.createdirectory lib.directory.export.removedirectory lib.directory.export.removefile lib.directory.export.renamedirectory lib.directory.export.renamefile lib.directory.export.getdirectorycontents lib.directory.export.getcurrentdirectory lib.directory.export.setcurrentdirectory lib.directory.export.doesfileexist lib.directory.export.doesdirectoryexist lib.directory.export.getpermissions lib.directory.export.setpermissions lib.directory.export.getmodificationtime
-- Report 22: module Directory exports each of these: an explicit import of every one compiles, and each name is used.
module Main (main) where

import Directory (Permissions( Permissions, readable, writable, executable, searchable ), createDirectory, removeDirectory, removeFile, renameDirectory, renameFile, getDirectoryContents, getCurrentDirectory, setCurrentDirectory, doesFileExist, doesDirectoryExist, getPermissions, setPermissions, getModificationTime)

t0 :: Permissions -> ()
t0 _ = ()
s0_0 _ = Permissions
s0_1 _ = readable
s0_2 _ = writable
s0_3 _ = executable
s0_4 _ = searchable

v1 _ = createDirectory

v2 _ = removeDirectory

v3 _ = removeFile

v4 _ = renameDirectory

v5 _ = renameFile

v6 _ = getDirectoryContents

v7 _ = getCurrentDirectory

v8 _ = setCurrentDirectory

v9 _ = doesFileExist

v10 _ = doesDirectoryExist

v11 _ = getPermissions

v12 _ = setPermissions

v13 _ = getModificationTime

main :: IO ()
main = return ()
