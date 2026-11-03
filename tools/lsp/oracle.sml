(* The oracle of what a language server keeps (docs/language-server.md, Keeping
   what is computed): one analysis context lives through a list of edits, and
   after each a fresh context analyses the same inputs. Every fact, occurrence,
   type, diagnostic and query must agree, whichever way the kept context got
   there; a difference is the failure that keeping can hide.

   Usage: rune-lsp-oracle --lib DIR --build FILE --scenarios FILE --out FILE
            [--focus] [--sample N] [--no-fresh] [--require PATH,...]

   A scenario is a line of tab-separated fields:
     NAME  REPS  FILE-SUFFIX  KIND  [ARG1  [ARG2]]
   and a line "+  FILE-SUFFIX  KIND ..." adds another edit to the one above it.
   FILE-SUFFIX names the last input that ends so: LAST the last, FIRST the
   first; it may also name a build file. KIND:
     append             a comment at the end
     prepend            a comment at the start
     appendtext ARG1    ARG1 at the end, $N the repetition
     replace ARG1 ARG2  the first ARG1 made ARG2, $N the repetition
     toggle ARG1 ARG2   as replace on odd repetitions, the original on even
     new ARG1           a new file of that name beside the input, holding ARG1
     complete ARG1      a query, at the end of the first ARG1
     cancel ARG1        the edit's next check is cancelled at poll ARG1 first
   In ARG1 and ARG2, \n is a newline. After its repetitions a scenario's files
   go back and one more check settles them.

   --focus keeps only the edited file open, as an editor does, and the sample
   of closed units compared opens them. --sample N compares N units besides the
   edited one, all of them without it. --no-fresh times the kept context alone.
   --require fails a run that did not take each of the paths named:
   placed walked rebound loaded cutoff broken failed cancelled query opened. *)
structure RuneLspOracle =
struct
  structure C=RuneCompiler
  structure A=C.Analysis
  fun read file=let val input=BinIO.openIn file
    in Byte.bytesToString (BinIO.inputAll input) before BinIO.closeIn input end
  fun num n=Int.toString n
  fun say text=(print text;TextIO.flushOut TextIO.stdOut)
  fun substitute (text,old,new)=
    let val (before',found)=Substring.position old (Substring.full text)
    in if Substring.isEmpty found then raise Fail ("no such text: " ^ old)
       else Substring.string before' ^ new ^ String.extract (text,Substring.size before'+size old,NONE) end
  fun fields (separator,text)=String.fields (fn c => c=separator) text
  (* a string with each $N made n *)
  fun expand (text,n)=
    let val pieces=ref [] val at=ref 0 val start=ref 0
        val count=size text
    in while !at<count do
         if !at+1<count andalso String.sub (text,!at)= #"$" andalso String.sub (text,!at+1)= #"N" then
           (pieces:=num n::String.substring (text,!start,!at- !start):: !pieces;at:= !at+2;start:= !at)
         else at:= !at+1;
       String.concat (List.rev (String.extract (text,!start,NONE):: !pieces)) end
  fun unescape text=
    let fun go ([],kept)=String.implode (List.rev kept)
          | go (#"\\" :: #"n" :: rest,kept)=go (rest,#"\n"::kept)
          | go (c::rest,kept)=go (rest,c::kept)
    in go (String.explode text,[]) end
  type edit={suffix:string,kind:string,arguments:string list}
  type scenario={name:string,repetitions:int,edits:edit list}
  fun parseScenarios text=
    let fun line (text,all)=
          if text="" orelse String.isPrefix "#" text then all else
          case fields (#"\t",text) of
            "+"::suffix::kind::arguments => (case all of
                {name,repetitions,edits}::rest =>
                  {name=name,repetitions=repetitions,edits=edits @ [{suffix=suffix,kind=kind,arguments=arguments}]}::rest
              | [] => raise Fail "a + line with no scenario")
          | name::repetitions::suffix::kind::arguments =>
              {name=name,repetitions=valOf (Int.fromString repetitions),edits=[{suffix=suffix,kind=kind,arguments=arguments}]}::all
          | _ => raise Fail ("not a scenario: " ^ text)
    in List.rev (List.foldl line [] (fields (#"\n",text))):scenario list end
  fun hex text=Hex.fromBytes (Sha256.digest text)
  fun location (NONE:A.location option)="-"
    | location (SOME {file,start,stop})=file ^ ":" ^ num start ^ ":" ^ num stop
  fun occurrenceText (o':A.occurrence)=String.concatWith "|" [#unit o',#file o',num (#start o'),num (#stop o'),#kind o',#name o',
    String.concatWith "." (#path o'),getOpt (#binding o',"-"),location (#definition o'),location (#declaration o'),
    Bool.toString (#isDefinition o'),Bool.toString (#derived o')]
  (* what occurrences say without what a definition's place in another file does *)
  fun looseText (o':A.occurrence)=String.concatWith "|" [#unit o',#file o',num (#start o'),num (#stop o'),#kind o',#name o',
    String.concatWith "." (#path o'),Bool.toString (#isDefinition o'),Bool.toString (#derived o')]
  fun factText (f:A.fact)=String.concatWith "|" [#unit f,#file f,num (#start f),num (#stop f),#ty f,Bool.toString (#derived f),
    String.concatWith "," (#constructors f),String.concatWith ";" (List.map (String.concatWith ",") (#arguments f))]
  fun typeText (t:A.typeDefinition)=String.concatWith "|" [#id t,location (#definition t),location (#declaration t),location (#implementation t)]
  fun diagnosticText (d:C.diagnostic)=String.concatWith "|" [#severity d,#file d,num (#start d),num (#stop d),num (#line d),num (#column d),#message d]
  fun candidateText (c:A.candidate)=String.concatWith "|" [#name c,#kind c,getOpt (#detail c,"-"),location (#definition c),
    String.concatWith ";" (List.map (String.concatWith ",") (#arguments c))]
  val paths=["placed","walked","rebound","loaded","cutoff","broken","failed","cancelled","query","opened"]
  fun main arguments =
    let val lib=ref "" val build=ref "" val scenariosFile=ref "" val out=ref ""
        val focusing=ref false val fresh=ref true val sample=ref ~1 val required=ref []
        fun options [] = ()
          | options ("--lib"::value::rest)=(lib:=value;options rest)
          | options ("--build"::value::rest)=(build:=value;options rest)
          | options ("--scenarios"::value::rest)=(scenariosFile:=value;options rest)
          | options ("--out"::value::rest)=(out:=value;options rest)
          | options ("--focus"::rest)=(focusing:=true;options rest)
          | options ("--no-fresh"::rest)=(fresh:=false;options rest)
          | options ("--sample"::value::rest)=(sample:=valOf (Int.fromString value);options rest)
          | options ("--require"::value::rest)=(required:=fields (#",",value);options rest)
          | options (other::_)=raise Fail ("unknown option: " ^ other)
        val ()=options arguments
        val compiler=C.session {lib=SOME (!lib),flags=[]}
        val output=TextIO.openOut (!out)
        fun emit fields=(TextIO.output (output,Json.encode (Json.Object fields) ^ "\n");TextIO.flushOut output)
        val overlays=ref [] : (string*string) list ref
        fun overlay file=Option.map #2 (List.find (fn (name,_) => name=file) (!overlays))
        fun textOf file=case overlay file of SOME text => text | NONE => read file
        fun setOverlay (file,text)=overlays:=(file,text)::List.filter (fn (name,_) => name<>file) (!overlays)
        fun dropOverlay file=overlays:=List.filter (fn (name,_) => name<>file) (!overlays)
        val workspaceFile=C.Workspace.find {file= !build,windows=false}
        (* read again where a build's text has changed *)
        val planned=ref NONE : (string*C.Project.t) option ref
        fun project ()=
          let val key=String.concat (List.concat (List.map (fn (file,text) =>
                if String.isSuffix ".build" file then [file,text] else [file]) (!overlays)))
          in case !planned of SOME (prior,value) => if prior=key then value else plan key | NONE => plan key end
        and plan key=
          let val value=C.Project.read (compiler,{file= !build,workspace=workspaceFile,variables=[],windows=false,
                overlays=List.map (fn (file,text) => {file=file,text=text}) (!overlays)})
          in planned:=SOME (key,value);value end
        val memo=ref [] : (string*string*string) list ref
        fun disk (file,mode)=case List.find (fn (name,other,_) => name=file andalso other=mode) (!memo) of
            SOME (_,_,text) => text
          | NONE =>
              let val bytes=read file
                  val text=if mode="unicode=latin1" then String.translate (fn byte => Utf8.encode (Char.ord byte)) bytes else bytes
              in memo:=(file,mode,text):: !memo;text end
        fun inputs ()=List.map (fn source:C.Project.source =>
          {file= #file source,mode= #mode source,annotations= #annotations source,revision="",
           text=case overlay (#file source) of SOME text => text | NONE => disk (#file source,#mode source)}:A.input)
          (C.Project.sources (project ()))
        val context=A.create (compiler,{context="kept"})
        val taken=ref [] : string list ref
        fun took path=if List.exists (fn other => other=path) (!taken) then () else taken:=path:: !taken
        val disagreements=ref 0
        val checks=ref 0
        val bindingsApart=ref 0
        fun checkIn (analysis,cancelled)=A.check (analysis,{project=SOME (project ()),inputs=inputs (),cancelled=cancelled})
        fun never ()=false
        (* a seeded choice of units, the same on every run *)
        val seed=ref 1
        fun next limit=(seed:=(!seed*1103515245+12345) mod 2147483648;if limit<=0 then 0 else !seed mod limit)
        fun compare (name,rep,kept:A.snapshot,edited:string list)=
          let val other=A.create (compiler,{context="fresh"})
              val fresh=checkIn (other,never)
              val bad=ref []
              fun differ what=(bad:=what:: !bad;disagreements:= !disagreements+1)
              fun same (what,left,right)=if left=right then () else
                (differ what;
                 let fun first ([],[])=() | first (x::_,[])=say ("  kept only: " ^ x ^ "\n") | first ([],y::_)=say ("  fresh only: " ^ y ^ "\n")
                       | first (x::xs,y::ys)=if x=y then first (xs,ys) else say ("  kept:  " ^ x ^ "\n  fresh: " ^ y ^ "\n")
                 in say ("  " ^ what ^ " differs, " ^ num (length left) ^ " against " ^ num (length right) ^ ":\n");first (left,right) end)
              val ()=same ("diagnostics",List.map diagnosticText (A.diagnostics kept),List.map diagnosticText (A.diagnostics fresh))
              val ()=same ("types",List.map typeText (A.types kept),List.map typeText (A.types fresh))
              val units=length (A.inputs kept)
              fun unitOf snapshot ordinal=A.unitAt (snapshot,{ordinal=ordinal})
              val ordinals=List.tabulate (units,fn i => i)
              fun touched ordinal=List.exists (fn file => #file (List.nth (A.inputs kept,ordinal))=file) edited
              val chosen=if !sample<0 then ordinals else
                List.filter touched ordinals @ List.tabulate (!sample,fn _ => next units)
              fun oneUnit ordinal=case (unitOf kept ordinal,unitOf fresh ordinal) of
                  (SOME a,SOME b) =>
                    if a<>b then differ ("the name of unit " ^ num ordinal) else
                    let val left=List.map occurrenceText (A.occurrencesIn (kept,a))
                        val right=List.map occurrenceText (A.occurrencesIn (fresh,b))
                        val leftLoose=List.map looseText (A.occurrencesIn (kept,a))
                        val rightLoose=List.map looseText (A.occurrencesIn (fresh,b))
                    in if left=right then () else
                         (if leftLoose=rightLoose then bindingsApart:= !bindingsApart+1 else ();
                          same ("occurrences of " ^ a,left,right));
                       same ("facts of " ^ a,List.map factText (A.factsIn (kept,a)),List.map factText (A.factsIn (fresh,b))) end
                | (NONE,NONE) => ()
                | _ => differ ("whether unit " ^ num ordinal ^ " was reached")
              val ()=List.app oneUnit chosen
              val ()=A.close other
          in if null (!bad) then () else say ("ORACLE " ^ name ^ " " ^ num rep ^ ": " ^ num (length (!bad)) ^ " disagreements\n");null (!bad) end
        fun measured (name,rep,edited,cancelAt)=
          let val ()=case cancelAt of NONE => () | SOME n =>
                let val polls=ref 0
                in (ignore (checkIn (context,fn () => (polls:= !polls+1;!polls>=n)));say ("  the cancelled check ended by itself\n"))
                   handle A.Cancelled => (took "cancelled";say ("  cancelled at poll " ^ num n ^ "\n")) end
              val before'=Runtime.stats ()
              val timer=Timer.startRealTimer ()
              val snapshot=checkIn (context,never)
              val seconds=Time.toReal (Timer.checkRealTimer timer)
              val after=Runtime.stats ()
              val {checked,reused}=A.work snapshot
              val {walked,rebound,loaded,cutoff,broken}=A.route snapshot
              val ()=(if walked then took "walked" else took "placed";
                      if rebound>0 then took "rebound" else ();if loaded>0 then took "loaded" else ();
                      if cutoff>0 then took "cutoff" else ();if broken>0 then took "broken" else ();
                      if null (A.diagnostics snapshot) then () else took "failed")
              val ()=checks:= !checks+1
              val agreed=if !fresh then SOME (compare (name,rep,snapshot,edited)) else NONE
          in emit ([("scenario",Json.String name),("rep",Json.int rep),("seconds",Json.Number (Real.toString seconds)),
               ("checked",Json.int checked),("reused",Json.int reused),("walked",Json.Bool walked),("rebound",Json.int rebound),
               ("loaded",Json.int loaded),("cutoff",Json.int cutoff),("broken",Json.int broken),
               ("diagnostics",Json.int (length (A.diagnostics snapshot))),("instructions",Json.int (#instructions after- #instructions before')),
               ("allocated",Json.int (#bytes after- #bytes before')),("live",Json.int (#live after))] @
               (case agreed of NONE => [] | SOME same => [("same",Json.Bool same)]));
             say (name ^ " " ^ num rep ^ ": " ^ Real.fmt (StringCvt.FIX (SOME 3)) seconds ^ " s, checked " ^ num checked ^ ", reused " ^ num reused ^
               (if walked then ", walked" else ", placed") ^ ", rebound " ^ num rebound ^ ", loaded " ^ num loaded ^ ", cutoff " ^ num cutoff ^ ", broken " ^ num broken ^
               (case A.diagnostics snapshot of [] => "" | d::_ => ", diagnostic: " ^ #file d ^ ":" ^ num (#line d) ^ ": " ^ #message d) ^
               (case agreed of NONE => "" | SOME true => ", same as fresh" | SOME false => ", DIFFERS FROM FRESH") ^ "\n");
             snapshot end
        val latest=ref (measured ("cold",0,[],NONE))
        fun fileFor suffix=
          let val all=List.map #file (inputs ())
              val builds=List.map #file (List.filter (fn input:C.Project.input => #kind input="build") (C.Project.inputs (project ())))
              fun last candidates=List.foldl (fn (file,found) => if String.isSuffix suffix file then SOME file else found) NONE candidates
          in if suffix="LAST" then List.last all else if suffix="FIRST" then hd all else
             case last (all @ builds) of SOME file => file | NONE => raise Fail ("no input ends " ^ suffix) end
        fun applied (kind,arguments,original,n)=case (kind,arguments) of
            ("append",_) => original ^ "\n(* edit " ^ num n ^ " *)\n"
          | ("prepend",_) => "(* edit " ^ num n ^ " *)\n" ^ original
          | ("appendtext",[text]) => original ^ "\n" ^ expand (unescape text,n) ^ "\n"
          | ("replace",[old,new]) => substitute (original,unescape old,expand (unescape new,n))
          | ("toggle",[old,new]) => if n mod 2=1 then substitute (original,unescape old,expand (unescape new,n)) else original
          | _ => raise Fail ("not a kind of edit: " ^ kind)
        fun query (name,suffix,text)=
          let val file=fileFor suffix
              val snapshot= !latest
              val all=A.inputs snapshot
              fun ordinal (_,[])=raise Fail "no such input"
                | ordinal (n,(input:A.input)::rest)=if #file input=file then n else ordinal (n+1,rest)
              val at=ordinal (0,all)
              val source= #text (List.nth (all,at))
              val (before',found)=Substring.position text (Substring.full source)
              val ()=if Substring.isEmpty found then raise Fail ("no such text: " ^ text) else ()
              val offset=Substring.size before'+size text
              val timer=Timer.startRealTimer ()
              val kept=A.visibleAt (snapshot,{ordinal=at,offset=offset,path=[]})
              val seconds=Time.toReal (Timer.checkRealTimer timer)
              val ()=took "query"
              val ()=say (name ^ ": a query at input " ^ num at ^ " of " ^ num (length all) ^ ": " ^
                Real.fmt (StringCvt.FIX (SOME 3)) seconds ^ " s, " ^ num (length kept) ^ " candidates\n")
          in if not (!fresh) then () else
             let val other=A.create (compiler,{context="fresh"})
                 val base=checkIn (other,never)
                 val answer=List.map candidateText (A.visibleAt (base,{ordinal=at,offset=offset,path=[]}))
             in if answer=List.map candidateText kept then () else
                  (disagreements:= !disagreements+1;say ("ORACLE " ^ name ^ ": the query differs from fresh\n"));
                A.close other end end
        fun scenario ({name,repetitions,edits}:scenario)=
          case edits of
            [{suffix,kind="complete",arguments=[text]}] => query (name,suffix,text)
          | _ =>
            let val cancelAt=case List.find (fn edit:edit => #kind edit="cancel") edits of
                  SOME {arguments=[n],...} => Int.fromString n | _ => NONE
                val edits=List.filter (fn edit:edit => #kind edit<>"cancel") edits
                val created=ref [] : string list ref
                val sites=List.map (fn {suffix,kind,arguments}:edit =>
                  if kind="new" then
                    let val file=OS.Path.concat (OS.Path.dir (fileFor "LAST"),suffix)
                    in created:=file:: !created;(file,"",kind,arguments) end
                  else let val file=fileFor suffix in (file,textOf file,kind,arguments) end) edits
                fun open' ()=if !focusing then A.focus (context,SOME (List.map #1 sites)) else ()
                val ()=open' ()
                fun apply n=List.app (fn (file,original,kind,arguments) =>
                  setOverlay (file,if kind="new" then expand (unescape (hd arguments),n) else applied (kind,arguments,original,n))) sites
                val edited=List.map #1 sites
                fun repeat n=if n>repetitions then () else
                  (apply n;latest:=measured (name,n,edited,if n=1 then cancelAt else NONE);repeat (n+1))
                val ()=repeat 1
                val ()=List.app (fn (file,original,_,_) => if original="" then dropOverlay file else setOverlay (file,original)) sites
                val ()=List.app dropOverlay (!created)
            in latest:=measured (name ^ "-restore",0,edited,NONE) end
        val ()=List.app scenario (parseScenarios (read (!scenariosFile)))
        val ()=if not (!focusing) orelse List.length (A.inputs (!latest))<2 then () else
          let val snapshot= !latest
              val ()=A.focus (context,SOME [])
              val closed=checkIn (context,never)
              val ordinal=length (A.inputs closed) div 2
              val unit=valOf (A.unitAt (closed,{ordinal=ordinal}))
          in if null (A.occurrencesIn (closed,unit)) then () else took "opened";ignore snapshot end
        val missing=List.filter (fn path => not (List.exists (fn other => other=path) (!taken))) (!required)
        val unknown=List.filter (fn path => not (List.exists (fn other => other=path) paths)) (!required)
        val ()=A.close context
        val ()=TextIO.closeOut output
        val ()=say ("checks " ^ num (!checks) ^ ", disagreements " ^ num (!disagreements) ^ " (only a definition's place in " ^ num (!bindingsApart) ^
          "), paths taken: " ^ String.concatWith " " (List.rev (!taken)) ^ "\n")
        val ()=if null missing andalso null unknown then () else
          say ("ORACLE a path not taken: " ^ String.concatWith " " (missing @ unknown) ^ "\n")
    in if !disagreements=0 andalso null missing andalso null unknown then OS.Process.success else OS.Process.failure end
    handle Fail message => (print ("rune-lsp-oracle: " ^ message ^ "\n");OS.Process.failure)
         | C.Failed diagnostics => (print ("rune-lsp-oracle: " ^ String.concatWith "\n" (List.map #message diagnostics) ^ "\n");OS.Process.failure)
end
