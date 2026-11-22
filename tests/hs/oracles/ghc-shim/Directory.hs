module Directory (
    Permissions( Permissions, readable, writable, executable, searchable ),
    createDirectory, removeDirectory, removeFile,
    renameDirectory, renameFile, getDirectoryContents,
    getCurrentDirectory, setCurrentDirectory,
    doesFileExist, doesDirectoryExist,
    getPermissions, setPermissions, getModificationTime
  ) where
import qualified System.Directory as D
import System.Directory (createDirectory, removeDirectory, removeFile, renameDirectory, renameFile,
    getDirectoryContents, getCurrentDirectory, setCurrentDirectory, doesFileExist, doesDirectoryExist)
import ShimTime (ClockTime, clockTimeOfPOSIX)
import Data.Time.Clock.POSIX (utcTimeToPOSIXSeconds)

data Permissions = Permissions { readable, writable, executable, searchable :: Bool }
  deriving (Eq, Ord, Read, Show)

getPermissions :: FilePath -> IO Permissions
getPermissions f = do
  p <- D.getPermissions f
  return (Permissions (D.readable p) (D.writable p) (D.executable p) (D.searchable p))

setPermissions :: FilePath -> Permissions -> IO ()
setPermissions f (Permissions r w e s) =
  D.setPermissions f (D.setOwnerSearchable s (D.setOwnerExecutable e (D.setOwnerWritable w (D.setOwnerReadable r D.emptyPermissions))))

getModificationTime :: FilePath -> IO ClockTime
getModificationTime f = do
  t <- D.getModificationTime f
  return (clockTimeOfPOSIX (toRational (utcTimeToPOSIXSeconds t)))
