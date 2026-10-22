(* Windows test storage is selected in SML; cmd/wslpath/cksum are bounded
   OS/path/CRC adapters. The worktree identity retains the old directory name. *)
structure WindowsDir =
struct
  open Sh
  exception Unavailable of string
  fun work ()=run ^ "/windows-directory/" ^ SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ()))
  fun command name cwd input args =
    let val dir=work ()
        val ()=mkdirs dir
        val status=Children.exec {addressSpace=NONE,cpuTime=SOME 30,fileSize=SOME (1024*1024),core=SOME 0} (fn e => e)
             {cmd=args,dir=SOME cwd,stdin=input,stdout=dir ^ "/" ^ name ^ ".out",stderr=dir ^ "/" ^ name ^ ".err",timeout=30}
    in if status=0 then read (dir ^ "/" ^ name ^ ".out") else raise Unavailable ("Windows path operation failed: " ^ name) end
  fun directory () =
    let val override=env ("RUNE_WINDOWS_DIR","")
        fun executable path=OS.FileSys.access (path,[OS.FileSys.A_EXEC]) andalso not (isDir path) handle OS.SysErr _ => false
        val directory=if override<>"" then override else
          let val paths=List.map (fn directory => OS.Path.concat (if directory="" then "." else directory,"cmd.exe"))
                                   (String.fields (fn ch => ch = #":") (env ("PATH","")))
              val cmd=case List.find executable paths of SOME path => OS.FileSys.fullPath path | NONE => "/mnt/c/Windows/System32/cmd.exe"
              val temp=Hosts.trim (String.translate (fn #"\r" => "" | ch => str ch)
                             (command "temp" "/mnt/c" "" [cmd,"/c","echo %TEMP%"]))
              val ()=if temp<>"" then () else raise Unavailable "Windows TEMP is empty"
              val temp=Hosts.trim (command "wslpath" root "" ["wslpath","-u",temp])
              val tree=OS.FileSys.realPath root
              val input=work () ^ "/tree"
              val ()=write (input,tree)
              val crc=case String.tokens Char.isSpace (command "crc" root input ["cksum"]) of sum :: _ => sum | [] => raise Unavailable "empty worktree CRC"
              val ()=if CharVector.all Char.isDigit crc then () else raise Unavailable "invalid worktree CRC"
          in temp ^ "/rune-test-windows/" ^ OS.Path.file tree ^ "-" ^ crc end
        val ()=mkdirs directory handle OS.SysErr _ => raise Unavailable "Windows test directory cannot be created"
    in OS.FileSys.fullPath directory end
end
