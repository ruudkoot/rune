(* Shared build/package model support. This file is Standard ML on a native
   host and on Rune; the process adapter is selected by the entrypoint. *)
structure BuildCommon =
struct
  exception Failed of string
  exception Usage of string
  fun need (ok,why)=if ok then () else raise Failed why
  fun env (name,fallback)=case OS.Process.getEnv name of SOME value => value | NONE => fallback
  val root=OS.Path.mkAbsolute {path=env ("RUNE_BUILD_ROOT",OS.FileSys.getDir ()),relativeTo=OS.FileSys.getDir ()}
  fun fromRoot path=OS.Path.mkAbsolute {path=path,relativeTo=root}
  fun exists file=OS.FileSys.access (file,[]) handle OS.SysErr _ => false
  fun isDir path=OS.FileSys.isDir path handle OS.SysErr _ => false
  fun isLink path=OS.FileSys.isLink path handle OS.SysErr _ => false
  fun trim text=Substring.string (Substring.dropr Char.isSpace (Substring.dropl Char.isSpace (Substring.full text)))
  fun fields ch text=String.fields (fn c => c=ch) text
  fun lines text=List.filter (fn s => s<>"") (fields #"\n" text)
  fun read file=let val input=BinIO.openIn file in Byte.bytesToString (BinIO.inputAll input) before BinIO.closeIn input end
  fun write (file,text)=let val output=BinIO.openOut file in BinIO.output (output,Byte.stringToBytes text);BinIO.closeOut output end
  fun mkdirs path =
    let fun loop (_,[])=() | loop (prefix,part::rest)=
          let val next=if prefix="" then if part="" then "/" else part else OS.Path.concat (prefix,part)
          in if part="" orelse isDir next then () else (OS.FileSys.mkDir next handle e as OS.SysErr _ => if isDir next then () else raise e);loop (next,rest) end
    in if path="" then () else loop ("",fields #"/" path) end
  fun remove path=if isLink path then OS.FileSys.remove path else if isDir path then
        (let val stream=OS.FileSys.openDir path
             fun loop ()=case OS.FileSys.readDir stream of NONE => () | SOME name => (remove (OS.Path.concat (path,name));loop ())
         in loop () before OS.FileSys.closeDir stream end;OS.FileSys.rmDir path) else OS.FileSys.remove path
       handle OS.SysErr _ => ()
  fun entries path=let val d=OS.FileSys.openDir path fun loop acc=case OS.FileSys.readDir d of NONE => List.rev acc | SOME name => loop (name::acc)
                    in loop [] before OS.FileSys.closeDir d end
  fun sort less values =
    let fun merge ([],ys)=ys | merge (xs,[])=xs | merge (xs as x::xr,ys as y::yr)=if less (y,x) then y::merge (xs,yr) else x::merge (xr,ys)
        fun loop []=[] | loop [x]=[x] | loop values=let val n=length values div 2 in merge (loop (List.take (values,n)),loop (List.drop (values,n))) end
    in loop values end
  fun resolved file =
    let val absolute=OS.Path.mkAbsolute {path=file,relativeTo=OS.FileSys.getDir ()}
        fun loop file depth =
          if depth>256 then raise Failed "symbolic link loop in build path" else
          if isLink file then let val target=OS.FileSys.readLink file
                 in loop (OS.Path.mkAbsolute {path=target,relativeTo=OS.Path.dir file}) (depth+1) end
          else if exists file then OS.FileSys.fullPath file else
            let val parent=OS.Path.dir file
            in if parent=file orelse parent="" then file else OS.Path.concat (loop parent (depth+1),OS.Path.file file) end
    in loop absolute 0 end
  fun sorted xs=sort (op <) xs
  fun unique xs=List.foldl (fn (v,old) => if List.exists (fn x => x=v) old then old else old @ [v]) [] xs
  fun tree path=if isDir path andalso not (isLink path) then List.concat (List.map (fn name => tree (OS.Path.concat (path,name))) (sorted (entries path))) else [path]
  fun hash file=
    let val input=BinIO.openIn file
        fun loop state=let val block=BinIO.inputN (input,65536) in if Word8Vector.length block=0 then Hex.fromBytes (Sha256.finish state)
                        else loop (Sha256.update (state,Byte.bytesToString block)) end
    in loop Sha256.empty before BinIO.closeIn input end
  fun copy source target=
    let val ()=mkdirs (OS.Path.dir target) val input=BinIO.openIn source val output=BinIO.openOut target
        fun loop ()=let val block=BinIO.inputN (input,65536) in if Word8Vector.length block=0 then () else (BinIO.output (output,block);loop ()) end
    in (loop () handle e => (BinIO.closeIn input;BinIO.closeOut output;raise e));BinIO.closeIn input;BinIO.closeOut output end
  fun copyTree source target =
    if isLink source then (mkdirs (OS.Path.dir target);Posix.FileSys.symlink {old=OS.FileSys.readLink source,new=target})
    else if isDir source then (mkdirs target;List.app (fn name => copyTree (source ^ "/" ^ name) (target ^ "/" ^ name)) (entries source);
       Posix.FileSys.chmod (target,Posix.FileSys.ST.mode (Posix.FileSys.stat source)))
    else (copy source target;Posix.FileSys.chmod (target,Posix.FileSys.ST.mode (Posix.FileSys.stat source)))
  fun privateDirectory parent label =
    let val ()=mkdirs parent
        fun attempt 0=raise Failed "cannot allocate a private build directory" | attempt n=
          let val reservation=OS.FileSys.tmpName () val path=parent ^ "/" ^ label ^ "-" ^ OS.Path.file reservation
              val ok=(OS.FileSys.mkDir path;true) handle OS.SysErr _ => false val ()=OS.FileSys.remove reservation
          in if ok then path else attempt (n-1) end
    in attempt 16 end
  fun atomic file text =
    let val directory=privateDirectory (OS.Path.dir file) ".publish" val pending=directory ^ "/payload"
    in (write (pending,text);OS.FileSys.rename {old=pending,new=file};remove directory) handle e => (remove directory;raise e) end
  fun say text=(TextIO.output (TextIO.stdOut,text);TextIO.flushOut TextIO.stdOut)
  fun warn text=(TextIO.output (TextIO.stdErr,text);TextIO.flushOut TextIO.stdErr)
  fun text (Json.String s)=s | text (Json.Number s)=s | text _=raise Failed "expected JSON string/number"
  fun array (Json.Array xs)=xs | array _=raise Failed "expected JSON array"
  fun object (Json.Object xs)=xs | object _=raise Failed "expected JSON object"
  fun field key value=case Json.member (key,value) of SOME value => value | NONE => raise Failed ("missing JSON member " ^ key)
  fun member key value=getOpt (Json.member (key,value),Json.Null)
  fun boolean (Json.Bool b)=b | boolean _=raise Failed "expected JSON boolean"
  fun str s=Json.String s
  fun strings xs=Json.Array (List.map str xs)
  fun number n=Json.Number (Int.toString n)
  fun set key value (Json.Object pairs)=Json.Object (List.filter (fn (old,_) => old<>key) pairs @ [(key,value)])
    | set _ _ _=raise Failed "expected JSON record"
  fun readJson file=Json.decode (read file)
  fun json file value=atomic file (Json.encode value ^ "\n")
  fun integer value=case Int.scan StringCvt.DEC Substring.getc (Substring.full value) of SOME (n,rest) => if Substring.isEmpty rest then n else raise Usage ("invalid integer " ^ value) | _ => raise Usage ("invalid integer " ^ value)
  fun real value=case Real.scan Substring.getc (Substring.full value) of SOME (n,rest) => if Substring.isEmpty rest andalso Real.isFinite n then n else raise Usage ("invalid number " ^ value) | _ => raise Usage ("invalid number " ^ value)
  fun minus s=String.translate (fn #"~" => "-" | c => String.str c) s
  fun version parts=List.map integer (fields #"." parts)
  fun setEnv (key,value) entries=(key ^ "=" ^ value)::List.filter (fn entry => not (String.isPrefix (key ^ "=") entry)) entries
  fun unset key entries=List.filter (fn entry => not (String.isPrefix (key ^ "=") entry)) entries
  fun quote text=if text<>"" andalso CharVector.all (fn c => Char.isAlphaNum c orelse Char.contains "_@%+=:,./-" c) text then text
                 else "'" ^ String.translate (fn #"'" => "'\"'\"'" | c => String.str c) text ^ "'"
  fun command args=String.concatWith " " (List.map quote args)
  fun words source =
    let val n=size source
        fun loop i quote escaped started current result =
          if i=n then (need (not escaped andalso not (isSome quote),"unterminated command quoting");List.rev (if started then String.implode (List.rev current)::result else result))
          else let val c=String.sub (source,i)
          in if escaped then loop (i+1) quote false true (c::current) result
             else case quote of SOME #"'" => if c = #"'" then loop (i+1) NONE false true current result else loop (i+1) quote false true (c::current) result
                 | SOME #"\"" => if c = #"\"" then loop (i+1) NONE false true current result else if c = #"\\" then loop (i+1) quote true true current result else loop (i+1) quote false true (c::current) result
                 | _ => if c = #"\\" then loop (i+1) NONE true true current result
                        else if c = #"'" orelse c = #"\"" then loop (i+1) (SOME c) false true current result
                        else if Char.isSpace c then if started then loop (i+1) NONE false false [] (String.implode (List.rev current)::result) else loop (i+1) NONE false false [] result
                        else loop (i+1) NONE false true (c::current) result end
    in loop 0 NONE false false [] [] end
  fun execute directory prefix timeout args environment =
    let val ()=mkdirs (OS.Path.dir prefix) val ()=json (prefix ^ ".command.json") (Json.Object [("argv",strings args),("cwd",str directory)])
        val result=BuildIO.execute {args=args,directory=directory,input="",output=prefix ^ ".stdout",errors=prefix ^ ".stderr",environment=environment,timeout=timeout}
        val ()=atomic (prefix ^ ".status") ("exit:" ^ Int.toString (#status result) ^ "\n")
    in {status= #status result,output=read (prefix ^ ".stdout"),errors=read (prefix ^ ".stderr"),seconds= #seconds result} end
  fun successful (result:{status:int,output:string,errors:string,seconds:real})=(need (#status result=0,trim (#errors result));trim (#output result))
end
