(* Shared measurement I/O and discrete result policy. Instrumentation,
   process timings and correctness remain separate at every call site. *)
structure MeasureCommon =
struct
  open Sh
  exception Failed of string
  exception Usage of string
  type result={status:int,output:string,errors:string}
  fun need (ok,why)=if ok then () else raise Failed why
  fun integer text=case Int.scan StringCvt.DEC Substring.getc (Substring.full text) of
        SOME (n,rest) => if Substring.isEmpty rest then n else raise Usage ("invalid integer: " ^ text)
      | NONE => raise Usage ("invalid integer: " ^ text)
  fun decimal text=case Real.scan Substring.getc (Substring.full text) of
        SOME (n,rest) => if Substring.isEmpty rest then n else raise Failed ("invalid number: " ^ text)
      | NONE => raise Failed ("invalid number: " ^ text)
  fun trim text=Substring.string (Substring.dropr Char.isSpace (Substring.dropl Char.isSpace (Substring.full text)))
  fun fields ch text=String.fields (fn c => c=ch) text
  fun tabs text=fields #"\t" text
  fun minus text=String.translate (fn #"~" => "-" | c => str c) text
  fun fixed digits value=minus (Real.fmt (StringCvt.FIX (SOME digits)) value)
  fun general value=
    let fun trim text=if not (String.isSubstring "." text) then text else
          let fun last n=if n>0 andalso String.sub (text,n-1) = #"0" then last (n-1) else n
              val n=last (size text)
              val n=if n>0 andalso String.sub (text,n-1) = #"." then n-1 else n
          in String.substring (text,0,n) end
        val scientific=minus (Real.fmt (StringCvt.SCI (SOME 5)) value)
    in case String.fields (fn c => c = #"E" orelse c = #"e") scientific of
         [mantissa,power] => let val exponent=case Int.fromString power of SOME n => n | NONE => raise Failed "invalid formatted exponent"
             in if exponent>= ~4 andalso exponent<6 then trim (fixed (Int.max (0,5-exponent)) value)
                else trim mantissa ^ "e" ^ (if exponent<0 then "-" else "+") ^ StringCvt.padLeft #"0" 2 (Int.toString (Int.abs exponent)) end
       | _ => String.map Char.toLower scientific
    end
  fun intText value=minus (IntInf.toString value)
  fun real value=Json.Number (minus (Real.toString value))
  fun big value=Json.Number (intText value)
  fun sorted less values =
    let fun merge ([],ys)=ys | merge (xs,[])=xs
          | merge (xs as x::xr,ys as y::yr)=if less (y,x) then y::merge (xs,yr) else x::merge (xr,ys)
        fun loop []=[] | loop [x]=[x] | loop xs=let val n=length xs div 2 in merge (loop (List.take (xs,n)),loop (List.drop (xs,n))) end
    in loop values end
  fun json file value=(mkdirs (OS.Path.dir file);write (file,Json.encode value ^ "\n"))
  fun text (Json.String value)=value | text _=raise Failed "expected JSON string"
  fun array (Json.Array values)=values | array _=raise Failed "expected JSON array"
  fun object (Json.Object fields)=fields | object _=raise Failed "expected JSON object"
  fun field name value=case Json.member (name,value) of SOME v => v | NONE => raise Failed ("missing JSON member: " ^ name)
  fun readJson file=(need (exists file,"missing JSON input: " ^ file);Json.decode (read file))
  fun binary file=let val stream=BinIO.openIn file in Byte.bytesToString (BinIO.inputAll stream) before BinIO.closeIn stream end
  fun hash file=
    let val stream=BinIO.openIn file
        fun loop state=let val bytes=BinIO.inputN (stream,65536)
                       in if Word8Vector.length bytes=0 then Hex.fromBytes (Sha256.finish state)
                          else loop (Sha256.update (state,Byte.bytesToString bytes)) end
        val digest=(loop Sha256.empty handle e => (BinIO.closeIn stream;raise e))
    in BinIO.closeIn stream;digest end
  fun copy source target =
    let val ()=mkdirs (OS.Path.dir target)
        val input=BinIO.openIn source val output=BinIO.openOut target
        fun loop ()=let val bytes=BinIO.inputN (input,65536) in if Word8Vector.length bytes=0 then () else (BinIO.output (output,bytes);loop ()) end
        val ()=(loop () handle e => (BinIO.closeIn input;BinIO.closeOut output;raise e))
    in BinIO.closeIn input;BinIO.closeOut output end
  fun files directory=if isDir directory andalso not (OS.FileSys.isLink directory) then
       List.concat (List.map (fn name => files (directory ^ "/" ^ name)) (sort (entries directory))) else [directory]
  fun copyTree source target =
    if OS.FileSys.isLink source then
       (mkdirs (OS.Path.dir target);Posix.FileSys.symlink {old=OS.FileSys.readLink source,new=target})
    else if isDir source then
       (mkdirs target;List.app (fn name => copyTree (source ^ "/" ^ name) (target ^ "/" ^ name)) (entries source);
        Posix.FileSys.chmod (target,Posix.FileSys.ST.mode (Posix.FileSys.stat source));OS.FileSys.setTime (target,SOME (OS.FileSys.modTime source)))
    else (copy source target;Posix.FileSys.chmod (target,Posix.FileSys.ST.mode (Posix.FileSys.stat source));OS.FileSys.setTime (target,SOME (OS.FileSys.modTime source)))
  fun tool name fallback=let val value=env (name,fallback)
                        in if exists value then [value] else CommandWords.split value end
  fun executable path=if String.isSubstring "/" path then OS.Path.mkAbsolute {path=path,relativeTo=OS.FileSys.getDir ()} else
       let val candidates=List.map (fn dir => OS.Path.concat (if dir="" then "." else dir,path)) (fields #":" (env ("PATH","")))
       in case List.find (fn file => OS.FileSys.access (file,[OS.FileSys.A_EXEC]) andalso not (isDir file) handle OS.SysErr _ => false) candidates of
            SOME file => OS.FileSys.fullPath file | NONE => raise Failed ("executable is unavailable: " ^ path) end
  fun status code=case code of Posix.Process.W_EXITED => 0 | Posix.Process.W_EXITSTATUS n => Word8.toInt n
       | Posix.Process.W_SIGNALED s => 128+SysWord.toInt (Posix.Signal.toWord s) | _ => 1
  fun measuredChild {args,directory,input,prefix,timeout,environment} =
    let val ()=mkdirs (OS.Path.dir prefix)
        val ()=json (prefix ^ ".command.json") (Json.Array (List.map Json.String args))
        val mode=Posix.FileSys.S.flags [Posix.FileSys.S.irusr,Posix.FileSys.S.iwusr,Posix.FileSys.S.irgrp,Posix.FileSys.S.iroth]
        val infd=if input="" then Posix.FileSys.openf ("/dev/null",Posix.FileSys.O_RDONLY,Posix.FileSys.O.flags [])
                 else Posix.FileSys.openf (input,Posix.FileSys.O_RDONLY,Posix.FileSys.O.flags [])
        val outfd=Posix.FileSys.creat (prefix ^ ".stdout",mode)
        val errfd=Posix.FileSys.creat (prefix ^ ".stderr",mode)
        fun close ()=(Posix.IO.close infd;Posix.IO.close outfd;Posix.IO.close errfd)
        fun number fd=SysWord.toInt (Posix.FileSys.fdToWord fd)
        (* Nested test actions remain in their supervisor's group. Public
           measurement runs own a group and reject a surviving descendant. *)
        val grouped=not (isSome (OS.Process.getEnv "RUNE_TEST_RUN") andalso isSome (OS.Process.getEnv "RUNE_TEST_CPUS"))
        val started=Runtime.clock ()
        val pid=(Subprocess.spawn {program=hd args,args=args,env=SOME (environment (Posix.ProcEnv.environ ())),search=not (String.isSubstring "/" (hd args)),
                    dir=SOME directory,stdin=SOME (number infd),stdout=SOME (number outfd),stderr=SOME (number errfd),group=grouped,
                    limits={addressSpace=NONE,cpuTime=NONE,fileSize=SOME (512*1024*1024),core=SOME 0}} handle e => (close ();raise e))
        val ()=close ()
        fun signal sigval=if grouped then Subprocess.kill (pid,sigval)
                 else Posix.Process.kill (Posix.Process.K_PROC (Posix.Process.wordToPid (SysWord.fromInt pid)),sigval)
        val usage=ref (Time.zeroTime,Time.zeroTime,0)
        fun ended result=(usage:=(#user result,#system result,#peakResident result);status (#status result))
        fun wait ()=case Subprocess.poll (SOME pid) of SOME result => ended result | NONE =>
              if timeout>0 andalso Time.>= (Time.- (Runtime.clock (),started),Time.fromSeconds (LargeInt.fromInt timeout)) then
                   ((signal Posix.Signal.kill handle OS.SysErr _ => ());ignore (Subprocess.wait (SOME pid));124)
              else (OS.Process.sleep (Time.fromMilliseconds 1);wait ())
        val code=(wait () handle e => ((signal Posix.Signal.kill handle OS.SysErr _ => ());ignore (Subprocess.wait (SOME pid)) handle OS.SysErr _ => ();raise e))
        val leaked=grouped andalso ((Subprocess.kill (pid,Posix.Signal.fromWord 0w0);true) handle OS.SysErr _ => false)
        val ()=if not leaked then () else (signal Posix.Signal.kill;append (prefix ^ ".stderr","measurement child left descendant processes\n"))
        val code=if leaked andalso code=0 then 1 else code
        val ()=write (prefix ^ ".status",Int.toString code ^ "\n")
    in {status=code,output=read (prefix ^ ".stdout"),errors=read (prefix ^ ".stderr"),wall=Time.- (Runtime.clock (),started),user= #1 (!usage),system= #2 (!usage),residentKB= #3 (!usage)} end
  fun child request=let val result=measuredChild request
        in {status= #status result,output= #output result,errors= #errors result} end
  fun execute directory prefix args=child {args=args,directory=directory,input="",prefix=prefix,timeout=600,environment=fn e => e}
  fun successful (result:result)=(need (#status result=0,"command failed: " ^ #errors result);#output result)
  fun inherited directory args =
    let val pid=Subprocess.spawn {program=hd args,args=args,search=not (String.isSubstring "/" (hd args)),env=NONE,dir=SOME directory,
                 stdin=NONE,stdout=NONE,stderr=NONE,group=false,limits=Subprocess.unlimited}
    in status (#status (Subprocess.wait (SOME pid))) end
  fun last []=NONE | last values=SOME (List.last values)
  fun prefixed prefix text=List.filter (String.isPrefix prefix) (lines text)
  fun find prefix text=last (prefixed prefix text)
  fun category {status,output,errors,failure} =
    if status=124 then "timeout" else if status=125 then "limit-setup-failure" else
    let val lower=String.map Char.toLower (errors ^ "\n" ^ output)
    in if List.exists (fn phrase => String.isSubstring phrase lower)
          ["out of memory","allocation failed","cannot allocate memory","heap limit","insufficient memory","unable to reserve"] then "memory-limit"
       else if status<>0 then failure else "pass" end
  fun validate {status,output,errors,rounds} =
    let val classified=category {status=status,output=output,errors=errors,failure="runtime-failure"}
        val incorrect=TerminalPattern.compile false "^FAIL .* -- (Fail: |Fail \")?(incorrect result|expected )"
        val classified=if isSome (TerminalPattern.find incorrect output 0) then "incorrect-result" else classified
    in if classified<>"pass" then classified else
       if List.exists (fn line => line="SUMMARY " ^ Int.toString rounds ^ " checks, 0 failed") (lines output)
          andalso length (prefixed "PASS " output)=rounds andalso null (prefixed "FAIL " output) then "pass" else "incorrect-result" end
end
