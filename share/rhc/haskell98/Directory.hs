-- Module Directory, section 22 of the Haskell 98 Report.
-- The code of the online Revised Report of December 2002, with its published
-- errata and rhc's overlay applied: a modified version of the Report's code,
-- which does not define Haskell 98. LICENSE says what was changed; errata.tsv
-- and overlay.tsv list each change, and pristine/ holds the code as printed.

module Directory ( 
    Permissions( Permissions, readable, writable, executable, searchable ), 
    createDirectory, removeDirectory, removeFile, 
    renameDirectory, renameFile, getDirectoryContents,
    getCurrentDirectory, setCurrentDirectory,
    doesFileExist, doesDirectoryExist,
    getPermissions, setPermissions,
    getModificationTime ) where

import Time ( ClockTime )
import PreludeBuiltin                   -- the system's calls, ClockTime's representation (rhc's)

data Permissions = Permissions {
			readable,   writable,
			executable, searchable :: Bool
		   }
		   deriving (Eq, Ord, Read, Show)   -- the four instances, elided (overlay ov.directory.permissions)



createDirectory 	:: FilePath -> IO ()
createDirectory d       =  primSystemCall "createDirectory" d (os_mkdir (primPackStr d))
removeDirectory 	:: FilePath -> IO ()
removeDirectory d       =  primSystemCall "removeDirectory" d (os_rmdir (primPackStr d))
removeFile 		:: FilePath -> IO ()
removeFile f            =  primSystemCall "removeFile" f (os_remove (primPackStr f))
renameDirectory 	:: FilePath -> FilePath -> IO ()
renameDirectory d d'    =  kindOf d >>= \k ->
                           if k /= 1 then ioError (IOError IllegalOperation ("renameDirectory: " ++ d ++ ": not a directory") Nothing (Just d))
                           else primSystemCall "renameDirectory" d (os_rename (primPackStr d) (primPackStr d'))
renameFile 		:: FilePath -> FilePath -> IO ()
renameFile f f'         =  kindOf f >>= \k ->
                           if k == 1 then ioError (IOError IllegalOperation ("renameFile: " ++ f ++ ": a directory") Nothing (Just f))
                           else primSystemCall "renameFile" f (os_rename (primPackStr f) (primPackStr f'))

-- 0 a file, 1 a directory, 2 a link, 3 other, -1 none
kindOf                  :: FilePath -> IO Int
kindOf f                =  os_file_kind (primPackStr f)

getDirectoryContents 	:: FilePath -> IO [FilePath]
getDirectoryContents d  =  os_open_dir (primPackStr d) >>= \s ->
                           if s < 0 then sys_errno >>= primFailWith ("getDirectoryContents: " ++ d) Nothing (Just d)
                           else names s ["..", "."]
  where names s acc = os_read_dir s >>= \n ->
                      if str_size n == 0 then os_close_dir s >> return (reverse acc)
                      else names s (primUnpackStr n : acc)
getCurrentDirectory 	:: IO FilePath
getCurrentDirectory     =  os_getcwd >>= \d ->
                           if str_size d == 0 then sys_errno >>= primFailWith "getCurrentDirectory" Nothing Nothing
                           else return (primUnpackStr d)
setCurrentDirectory 	:: FilePath -> IO ()
setCurrentDirectory d   =  primSystemCall "setCurrentDirectory" d (os_chdir (primPackStr d))

doesFileExist		:: FilePath -> IO Bool
doesFileExist f         =  kindOf f >>= \k -> return (k >= 0 && k /= 1)
doesDirectoryExist	:: FilePath -> IO Bool
doesDirectoryExist d    =  kindOf d >>= \k -> return (k == 1)

getPermissions		:: FilePath -> IO Permissions
getPermissions f        =  kindOf f >>= \k ->
                           if k < 0 then sys_errno >>= primFailWith ("getPermissions: " ++ f) Nothing (Just f)
                           else may 1 >>= \r -> may 2 >>= \w -> may 4 >>= \x ->
                                return (Permissions { readable = r, writable = w,
                                                      executable = x && k /= 1, searchable = x && k == 1 })
  where may bit = os_access (primPackStr f) bit >>= \a -> return (a == 1)
setPermissions		:: FilePath -> Permissions -> IO ()
setPermissions f p      =  os_file_mode (primPackStr f) >>= \mode ->
                           if mode < 0 then sys_errno >>= primFailWith ("setPermissions: " ++ f) Nothing (Just f)
                           else primSystemCall "setPermissions" f
                                  (os_set_mode (primPackStr f)
                                     (mode - (mode `mod` 512 - mode `mod` 64)
                                      + (if readable p then 256 else 0) + (if writable p then 128 else 0)
                                      + (if executable p || searchable p then 64 else 0)))

getModificationTime	:: FilePath -> IO ClockTime
getModificationTime f   =  os_mod_time (primPackStr f) >>= \t ->
                           if t < 0 then sys_errno >>= primFailWith ("getModificationTime: " ++ f) Nothing (Just f)
                           else return (ClockTime (toInteger t) 0)

