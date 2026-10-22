(* Bounded duplex I/O on an owned pseudo-terminal. Screen assertions and
   raw-byte assertions consume the same stream, with monotonic deadlines. *)
structure TerminalIO =
struct
  exception Failed of string
  fun outputLimit ()=case OS.Process.getEnv "TERMINAL_OUTPUT_LIMIT" of NONE => 32*1024*1024
       | SOME value => (case Int.fromString value of SOME n => if n>0 andalso n<=32*1024*1024 then n else raise Failed "invalid terminal output limit"
                       | NONE => raise Failed "invalid terminal output limit")
  type terminal={session:Pty.session,screen:Emulator.screen ref,raw:string ref,ended:Subprocess.ended option ref,eof:bool ref}
  fun input session=Posix.FileSys.wordToFD (SysWord.fromInt (Pty.input session))
  fun output session=Posix.FileSys.wordToFD (SysWord.fromInt (Pty.output session))
  fun spawn {args,environment,directory,columns,rows} : terminal =
    let val session=Pty.spawn {program=hd args,args=args,env=SOME environment,dir=SOME directory,columns=columns,rows=rows}
        fun nonblocking fd=let val (flags,_)=Posix.IO.getfl fd in Posix.IO.setfl (fd,Posix.IO.O.flags [flags,Posix.IO.O.nonblock]) end
        val ()=(List.app nonblocking [input session,output session] handle e =>
              ((Subprocess.kill (Pty.process session,Posix.Signal.kill) handle OS.SysErr _ => ());Pty.close session;
               ignore (Subprocess.wait (SOME (Pty.process session)));raise e))
    in {session=session,screen=ref (Emulator.new {columns=columns,rows=rows,policy=Grapheme.ByCluster}),raw=ref "",ended=ref NONE,eof=ref false} end
  fun again NONE=false
    | again (SOME code)=List.exists (fn name => OS.syserror name=SOME code) ["again","wouldblock"]
  fun status (t : terminal)=case !(#ended t) of SOME ended => SOME ended | NONE =>
         let val ended=Subprocess.poll (SOME (Pty.process (#session t))) in #ended t:=ended;ended end
  fun poll fd write delay =case OS.IO.pollDesc (Posix.FileSys.fdToIOD fd) of NONE => raise Failed "terminal descriptor cannot be polled"
        | SOME p => not (null (OS.IO.poll ([if write then OS.IO.pollOut p else OS.IO.pollIn p],SOME delay)))
  fun read (t : terminal) delay =
    if !(#eof t) orelse not (poll (input (#session t)) false delay) then false else
    let val data=SOME (Posix.IO.readVec (input (#session t),65536)) handle OS.SysErr (_,error) =>
             if again error then NONE else if error=OS.syserror "io" then SOME (Word8Vector.fromList []) else raise OS.SysErr ("terminal read failed",error)
    in case data of NONE => false | SOME data =>
    let
        val text=Byte.bytesToString data
    in if text="" then (#eof t:=true;false) else
       (if size (!(#raw t))+size text>outputLimit () then raise Failed "terminal output exceeds its limit" else ();
        #raw t:= !(#raw t) ^ text;#screen t:=Emulator.write (!(#screen t),text);true) end end
  fun drain t=if read t Time.zeroTime then drain t else ()
  fun write (t : terminal) text =
    let val bytes=Byte.stringToBytes text
        val deadline=Time.+ (Runtime.clock (),Time.fromSeconds 20)
        fun loop at=if at=Word8Vector.length bytes then () else
          if Time.>= (Runtime.clock (),deadline) then raise Failed "terminal input timed out" else
          (drain t;
           if not (poll (output (#session t)) true (Time.fromMilliseconds 20)) then loop at else
             let val count=Posix.IO.writeVec (output (#session t),Word8VectorSlice.slice (bytes,at,SOME (Int.min (1024,Word8Vector.length bytes-at))))
                               handle OS.SysErr (_,error) => if again error then 0 else raise OS.SysErr ("terminal write failed",error)
             in if count=0 then (OS.Process.sleep (Time.fromMilliseconds 1);loop at) else loop (at+count) end)
    in loop 0 end
  fun quiet t duration =
    let val deadline=Time.+ (Runtime.clock (),Time.fromSeconds 20)
        fun loop ()=if Time.>= (Runtime.clock (),deadline) then raise Failed "terminal never became quiet"
                    else if read t duration then loop () else ()
    in loop () end
  fun code (ended : Subprocess.ended)=case #status ended of Posix.Process.W_EXITED => 0
       | Posix.Process.W_EXITSTATUS n => Word8.toInt n | Posix.Process.W_SIGNALED s => 128+SysWord.toInt (Posix.Signal.toWord s)
       | _ => raise Failed "terminal process stopped unexpectedly"
  fun wait (t : terminal) seconds =
    let val deadline=Time.+ (Runtime.clock (),Time.fromReal seconds)
        fun loop ()=(drain t;case status t of SOME ended => (quiet t (Time.fromMilliseconds 50);code ended)
             | NONE => if Time.>= (Runtime.clock (),deadline) then raise Failed "terminal child did not exit" else
                 (ignore (read t (Time.fromMilliseconds 20));loop ()))
    in loop () end
  fun resize (t : terminal) size=(drain t;#screen t:=Emulator.resize (!(#screen t),size);Pty.resize (#session t,size))
  fun close (t : terminal)=
    let val ended=status t
        (* A shell may have exited while a background program still owns
           its controlling terminal. End the whole group before disconnect. *)
        val ()=(Subprocess.kill (Pty.process (#session t),Posix.Signal.kill) handle OS.SysErr _ => ())
        val ()=case ended of SOME _ => () | NONE => ignore (Subprocess.wait (SOME (Pty.process (#session t))))
    in Pty.close (#session t) end
  fun styled (t : terminal) =
    let val plain=Emulator.text (!(#screen t))
        val count=length (String.fields (fn c => c = #"\n") plain)
        fun line i=
          let fun sgr style=let val text=Style.sgr style
                               val params=String.substring (text,2,size text-3)
                           in "\027[" ^ (if String.isPrefix "0;" params then String.extract (params,2,NONE) else params) ^ "m" end
              fun attributes (s:Style.style)= #bold s orelse #faint s orelse #italic s orelse #underline s orelse #reverse s orelse #struck s
              fun change (previous:Style.style,style:Style.style)=
                if style=previous then "" else if style=Style.plain then
                  if attributes previous then "\027[0m" else
                    (if #fg previous<>Style.Default then "\027[39m" else "") ^ (if #bg previous<>Style.Default then "\027[49m" else "")
                else (if attributes previous then "\027[0m" else "") ^ sgr style ^
                     (if #fg style=Style.Default andalso #fg previous<>Style.Default then "\027[39m" else "")
              fun loop [] _=""
                | loop (({text,style}:Emulator.cell)::rest) previous=
                   change (previous,style) ^ text ^ loop rest style
          in loop (Emulator.row (!(#screen t),i)) Style.plain end
    in String.concatWith "\n" (List.tabulate (count,line)) end
end
