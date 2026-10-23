(* The C oracle reports native facts and independently evaluates expressions.
   The SML consumer parses the original fixture and compares every result. *)
structure CLayoutChecks =
struct
  open Sh
  exception Failed of string
  fun need(ok,message)=if ok then () else raise Failed message
  val directory=run ^ "/c-layout/" ^ SysWord.toString(Posix.Process.pidToWord(Posix.ProcEnv.getpid()))
  fun command name args=
    let val ()=mkdirs directory
        val out=directory ^ "/" ^ name ^ ".out" val err=directory ^ "/" ^ name ^ ".err"
        val status=Children.exec Subprocess.unlimited(fn e=>e){cmd=args,dir=SOME root,stdin="",stdout=out,stderr=err,timeout=120}
    in need(status=0,name ^ " exited " ^ Int.toString status ^ ": " ^ read err); read out end
  fun compiler target=
    let val clang=String.tokens Char.isSpace(env("CLANG","clang"))
        fun cross triple root=clang @ ["--target=" ^ triple,"-B" ^ root ^ "/bin","-L" ^ root ^ "/lib","-I" ^ root ^ "/include",
          "-Wl,-rpath," ^ root ^ "/lib"]
    in case target of "native"=>String.tokens Char.isSpace(env("CC","cc"))
      | "linux32"=>String.tokens Char.isSpace(env("CC","cc")) @ ["-m32"]
      | "windows32"=>String.tokens Char.isSpace(env("WINCC32","i686-w64-mingw32-gcc"))
      | "windows64"=>String.tokens Char.isSpace(env("WINCC","x86_64-w64-mingw32-gcc"))
      | "aarch64"=>cross "aarch64-linux-gnu" "/usr/aarch64-linux-gnu"
      | "ppc64"=>cross "powerpc64-linux-gnu" "/usr/powerpc64-linux-gnu"
      | _=>raise Failed "unknown native layout target" end
  fun runner "aarch64"=["qemu-aarch64","-L","/usr/aarch64-linux-gnu"]
    | runner "ppc64"=["qemu-ppc64","-L","/usr/powerpc64-linux-gnu"] | runner _=[]
  fun number s=case Int.fromString s of SOME n=>n | NONE=>raise Failed("not an integer: " ^ s)
  fun large s=case IntInf.fromString s of SOME n=>n | NONE=>raise Failed("not an integer: " ^ s)
  fun main [name]=
    let val executable=directory ^ "/oracle" ^ (if String.isPrefix "windows" name then ".exe" else "")
        val ()=ignore(command "compile"(compiler name @ ["-std=c11","-Wall","-Wextra","-Werror","-Wno-sign-compare","-pedantic",
          "tests/ffi/layout_oracle.c","-o",executable]))
        val output=String.translate(fn #"\r"=>"" | c=>str c)(command "oracle"(runner name @ [executable]))
        val rows=lines output
        val facts=List.mapPartial(fn row=>case String.fields(fn c=>c= #":")row of
          [name,size,align]=>SOME(CType.canonical name,{size=number size,alignment=number align,signed=NONE}) | _=>NONE)rows
        fun fact name=case List.find(fn(n,_)=>n=name)facts of SOME(_,f)=>f | NONE=>raise Failed("missing C fact: " ^ name)
        fun setting key=case List.find(String.isPrefix(key ^ ":"))rows of
          SOME s=>String.extract(s,size key+1,NONE) | NONE=>raise Failed("missing C setting: " ^ key)
        val integers={char= #size(fact "char")*8,short= #size(fact "short")*8,int= #size(fact "int")*8,
          long= #size(fact "long")*8,longLong= #size(fact "long long")*8}
        val charSigned=setting "charSigned"="1"
        val sizeType=valOf(CType.integer{target=integers,charSigned=charSigned,ty=CParse.Builtin(setting "sizeType")})
        val target={name=name,pointer=fact "void *",enumeration=fact "int",
          maximumObject=IntInf.-(IntInf.<<(1,Word.fromInt(#size(fact "void *")*8)),1),
          scalars=facts @ List.map(fn s=>("unsigned " ^ s,fact s))["char","short","int","long","long long"] @
            [("signed char",fact "char"),("_Bool",fact "char")]}
        val declarations= #declarations(CParse.translationUnit{tokens=CLex.scan{file="tests/ffi/layout.h",text=read(fromRoot "tests/ffi/layout.h")},predefinedTypes=[]})
        fun lookup{namespace,name}=List.find(fn CParse.Record{kind,tag=SOME n,...}=>n=name andalso
              namespace=(case kind of CParse.Struct=>"struct" | CParse.Union=>"union") | _=>false)
          (List.mapPartial(fn CParse.Declaration{ctype,...}=>SOME ctype | _=>NONE)declarations)
        fun measure ty=let val l=layout ty in {size=CLayout.size l,alignment=CLayout.alignment l} end
        and layout ty=CLayout.compute{target=target,source={file="tests/ffi/layout.h",line=1,column=1},ty=ty,lookup=lookup,
              constant=fn tokens=> #integer(eval tokens)}
        and eval tokens=CExpression.evaluate{target=integers,sizeType=sizeType,tokens=tokens,lookup=fn _=>NONE,
              resolveType=fn tokens=>CType.parse{tokens=tokens,typedefs=[]},
              integerType=fn ty=>CType.integer{target=integers,charSigned=charSigned,ty=ty},measure=measure}
        val count=ref 0
        fun one row=case String.fields(fn c=>c= #"|")row of
          ["expression",expression,expected,expectedType]=>
            let val actual=eval(CLex.scan{file="native-expression.c",text=expression})
            in need(#integer actual=large expected andalso CType.spelling(#ty actual)=expectedType,
                 name ^ " C expression differs: " ^ row ^ " versus " ^ IntInf.toString(#integer actual) ^ ":" ^ CType.spelling(#ty actual));count:= !count+1 end
        | ["layout",ty,expectedSize,expectedAlign,member,expectedOffset]=>
            let val l=layout(CParse.typeName{tokens=CLex.scan{file="native-type.c",text=ty},predefinedTypes=[]})
            in need(CLayout.size l=large expectedSize andalso CLayout.alignment l=number expectedAlign andalso
                 #offset(CLayout.member(l,[member]))=large expectedOffset,name ^ " C layout differs: " ^ row);count:= !count+1 end
        | _=>()
        val ()=List.app one rows
        val ()=need(!count=23,"native oracle comparison lost cases")
    in say("PASS target C layout/expressions: " ^ name ^ ": " ^ Int.toString(!count) ^ " native comparisons\n") end
    | main _=raise Failed "expected native, linux32, windows32, windows64, aarch64 or ppc64"
end
val ()=CLayoutChecks.main(CommandLine.arguments()) handle e=>
  (TextIO.output(TextIO.stdErr,"FAIL C layout: " ^ (case e of CLayoutChecks.Failed s=>s
    | CExpression.Error(_,s)=>s | CParse.Error(_,s)=>s | CLayout.Error(_,s)=>s | CLayout.Shim(_,s)=>s | _=>General.exnMessage e) ^ "\n");
   OS.Process.exit OS.Process.failure)
