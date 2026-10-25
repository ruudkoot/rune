(* IntInf child-process contract: isolated streams, clean backend policy,
   finite deadlines and sanitizer-aware memory limits. Arithmetic answers are
   preserved independent fixtures, never calculated by the backend under test. *)
structure IntInfChecks =
struct
  open Sh
  exception Failed of string
  type context = {directory : string, compiler : string, vm : string, smlVM : string,
                  target : string, vmOptions : string list, stress : bool, sequence : int ref}
  type result = {status : int, output : string, errors : string, prefix : string}
  fun need (ok,why) = if ok then () else raise Failed why
  fun create name : context =
    {directory=run ^ "/intinf/" ^ name,compiler=fromRoot (env ("INTINF_RUNE","bin/rune")),
     vm=fromRoot (env ("INTINF_VM","bin/runevm")),smlVM=fromRoot (env ("INTINF_SML_VM","bin/runevm-sml")),
     target=env ("INTINF_TARGET","registers"),vmOptions=CommandWords.split (env ("INTINF_VM_OPTIONS","")),
     stress=env ("INTINF_STRESS","0")="1",sequence=ref 0}
  fun path (c : context) name = #directory c ^ "/" ^ name
  fun environment overrides values =
    let val values = List.filter (fn value => not (String.isPrefix "RUNEVM_" value) andalso not (String.isPrefix "RUNE_GC_STRESS=" value)) values
    in List.foldl (fn ((key,value),values) => setEnv (key,value) values) (setEnv ("LC_ALL","C") values) overrides end
  fun execute (c : context) label timeout overrides args : result =
    let val () = mkdirs (#directory c)
        val () = #sequence c := !(#sequence c)+1
        val prefix = path c (StringCvt.padLeft #"0" 3 (Int.toString (!(#sequence c))) ^ "-" ^ label)
        val args = case args of program :: rest => if program = #vm c orelse program = #smlVM c then program :: #vmOptions c @ rest else args | [] => raise Failed "empty IntInf command"
        val () = write (prefix ^ ".command.json",Json.encode (Json.Array (List.map Json.String args)) ^ "\n")
        val () = if null overrides then () else write (prefix ^ ".environment.json",Json.encode (Json.Object (List.map (fn (key,value) => (key,Json.String value)) overrides)) ^ "\n")
        val status = Children.exec {addressSpace=if String.isSubstring "asan" (hd args) then NONE else SOME (4*1024*1024*1024),
                                   cpuTime=NONE,fileSize=SOME (64*1024*1024),core=SOME 0} (environment overrides)
             {cmd=args,dir=SOME root,stdin="",stdout=prefix ^ ".stdout",stderr=prefix ^ ".stderr",timeout=timeout}
        val () = write (prefix ^ ".status",Int.toString status ^ "\n")
    in need (status <> 124,"IntInf process timed out: " ^ label); {status=status,output=read (prefix ^ ".stdout"),errors=read (prefix ^ ".stderr"),prefix=prefix} end
  fun run c label args = execute c label 180 [] args
  fun success (result : result) = need (#status result=0,"IntInf command failed (" ^ Int.toString (#status result) ^ "): " ^ #errors result)
  fun output (result : result) expected = (success result; need (#output result=expected,"IntInf output differs: " ^ String.toString (#output result)))
  fun rejected (result : result) message = need (#status result=2 andalso String.isSubstring message (#errors result),
          "expected IntInf refusal " ^ message ^ "; exit " ^ Int.toString (#status result) ^ ": " ^ #errors result)
  (* compileWith overrides: the compiler run with the environment's
     overrides, as execute takes them *)
  fun compileWith overrides (c : context) name source target extra =
    let val file = path c (name ^ ".sml")
        val rbc = path c (name ^ ".rbc")
        val () = (mkdirs (#directory c); write (file,source); rmTree rbc)
        val result = execute c (name ^ "-compile") 180 overrides ([#compiler c,"--target=" ^ target,"-o",rbc] @ extra @ [file])
    in success result; need (exists rbc andalso OS.FileSys.fileSize rbc > 0,"IntInf compiler produced no bytecode"); rbc end
  fun compile c name source target extra = compileWith [] c name source target extra
  fun field key value = case Json.member (key,value) of SOME value => value | NONE => raise Failed ("missing IntInf fixture field " ^ key)
  fun string (Json.String text) = text | string _ = raise Failed "IntInf fixture expected string"
  fun array (Json.Array rows) = rows | array _ = raise Failed "IntInf fixture expected array"
  fun object (Json.Object rows) = rows | object _ = raise Failed "IntInf fixture expected object"
  fun fixture name = Json.decode (read (fromRoot ("tests/intinf/fixtures/" ^ name ^ "-v1.json")))
  fun source c group name =
    let val fields = object (field "fragments" (fixture group))
        val text = case List.find (fn (key,_) => key=name) fields of SOME (_,text) => string text | NONE => raise Failed ("missing IntInf source " ^ group ^ "/" ^ name)
    in if String.isSubstring "$IMAGE" text then Incremental.replace text "$IMAGE" (String.toString (path c (if group="hardening" then "policy.img" else "world.img"))) else text end
  fun hasGMP c =
    let val result = run c "version" [#vm c,"--version"]
    in success result; String.isSubstring "GMP headers " (#output result) andalso String.isSubstring ", supported\n" (#output result) end
  fun invoke (c : context) vm mode program flags interval =
    run c (mode ^ "-run") ([vm,"--intinf=" ^ mode,"--intinf-stats"]
              @ (if #stress c then ["--gc-stress",Int.toString interval] else []) @ flags @ [program])
  fun after marker text =
    let val (_,rest) = Substring.position marker (Substring.full text)
    in if Substring.isEmpty rest then NONE else SOME (Substring.string (Substring.triml (size marker) rest)) end
  fun stats result =
    let val words = String.tokens (fn c => Char.isSpace c orelse c = #",") (#errors (result : result))
        fun beforeTokens suffix =
          let fun find (n :: rest) = if List.take (rest,Int.min (length suffix,length rest))=suffix then SOME n else find rest | find [] = NONE
          in find words end
    in (beforeTokens ["GMP","calls"],beforeTokens ["GMP","live"]) end
  fun correctStats result gmp =
    let val (calls,live) = stats result
        val calls = Option.mapPartial IntInf.fromString calls
    in need (live=SOME "0" andalso (case calls of SOME n => (n>0)=gmp | NONE => false),"IntInf backend call/live counters differ") end
  fun semanticWithVectors (c : context) vm options vectorFile =
    let val () = mkdirs (#directory c)
        val vectors = path c "vectors.sml"
        val () = Incremental.copy vectorFile vectors
        val rbc = path c "checks.rbc"
        val () = rmTree rbc
        val result = run c "checks-compile" [#compiler c,"--lib","lib","--target=" ^ #target c,"-o",rbc,
                    fromRoot "tests/intinf/oracle.sml",vectors,fromRoot "tests/intinf/checks.sml"]
        val () = success result
        val result = run c "checks" (vm :: options @ [rbc])
        val () = output result "current: 1154 checks\noracle: 1154 checks\n"
    in rbc end
  fun semantic c vm options = semanticWithVectors c vm options (fromRoot "tests/intinf/fixtures/vectors.sml")
  fun options (c : context) () =
    let val cases=[("--intinf-max-bits","64",true),("--intinf-max-bits","1073741822",true),
         ("--intinf-max-bits","63",false),("--intinf-max-bits","1073741823",false),("--intinf-max-bits","0",false),
         ("--intinf-max-bits","-1",false),("--intinf-max-bits","18446744073709551616",false),
         ("--intinf-gmp-memory","1",true),("--intinf-gmp-memory","0",false),("--intinf-gmp-memory","-1",false),("--intinf-gmp-memory","1x",false)]
        fun one (flag,value,valid) = let val result=execute c "option" 10 [] [#vm c,flag,value,"--version"]
                                    in need (#status result=(if valid then 0 else 2),"IntInf option boundary: " ^ flag ^ " " ^ value) end
    in List.app one cases; say "PASS IntInf option bounds: 11 checks\n" end
end
