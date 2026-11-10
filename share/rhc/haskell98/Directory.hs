-- Module Directory, section 22 of the Haskell 98 Report.
-- The code of the online Revised Report of December 2002 with its published
-- errata applied: a modified version of the Report's code, which does not
-- define Haskell 98. LICENSE says what was changed; errata.tsv and
-- overlay.tsv list each change, and pristine/ holds the code as printed.

module Directory ( 
    Permissions( Permissions, readable, writable, executable, searchable ), 
    createDirectory, removeDirectory, removeFile, 
    renameDirectory, renameFile, getDirectoryContents,
    getCurrentDirectory, setCurrentDirectory,
    doesFileExist, doesDirectoryExist,
    getPermissions, setPermissions,
    getModificationTime ) where

import Time ( ClockTime )

data Permissions = Permissions {
			readable,   writable,
			executable, searchable :: Bool
		   }

instance Eq   Permissions where ...
instance Ord  Permissions where ...
instance Read Permissions where ...
instance Show Permissions where ...



createDirectory 	:: FilePath -> IO ()
removeDirectory 	:: FilePath -> IO ()
removeFile 		:: FilePath -> IO ()
renameDirectory 	:: FilePath -> FilePath -> IO ()
renameFile 		:: FilePath -> FilePath -> IO ()

getDirectoryContents 	:: FilePath -> IO [FilePath]
getCurrentDirectory 	:: IO FilePath
setCurrentDirectory 	:: FilePath -> IO ()

doesFileExist		:: FilePath -> IO Bool
doesDirectoryExist	:: FilePath -> IO Bool

getPermissions		:: FilePath -> IO Permissions
setPermissions		:: FilePath -> Permissions -> IO ()

getModificationTime	:: FilePath -> IO ClockTime

