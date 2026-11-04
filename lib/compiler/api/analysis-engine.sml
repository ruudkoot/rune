(* Static unit replay, held between checks. A unit stays loaded in the session
   of a world, a compiler state of its own, with the place it was reached at:
   a changed unit is elaborated at that place, and nothing else is touched
   while its identity stands. Where one moves, a walk from the start takes
   each unit after it by its usages, as a build takes an entry of the cache.
   Nothing here decides anything a fresh analysis would not (docs/language-server.md,
   Keeping what is computed): tools/lsp/oracle.sml holds it to one. *)
structure CompilerAnalysisEngine =
struct
  type source={file:string,text:string,mode:Source.mode}
  type candidate={name:string,kind:string,detail:string option,arguments:string list list,origin:Env.origin}
  type application={name:string,path:string list,argument:int,parameter:int}
  type scopeQuery={unit:string,file:string,offset:int,path:string list}
  type fact={unit:string,file:string,start:int,stop:int,ty:string,derived:bool,constructors:string list,arguments:string list list}
  type typeDefinition={id:string,origin:Env.origin}
  type use=string*(string list*string)*Source.span*Env.origin*bool
  (* A type name a unit's facts print, and how they printed it: by the
     identity of its unit and its number there, or built in (unit "") by its
     stamp. A unit's own that no path reaches is none of these: it prints by
     its name wherever the unit is. Facts print so again where each of these
     does (printsSo): a path depends on the whole environment, which no
     usage says (docs/language-server.md, The sidecar) *)
  type printed={unit:string,number:int,name:string,arity:int,eq:bool,shown:string option}
  (* A unit's results. syntax and typing (what the editor's types are worked
     out from when first asked, CompilerNodeTypes, for a unit of the inputs),
     facts and uses are a unit's that is open, and printed what its facts
     printed. A closed unit holds no syntax, no typing and no facts, and of
     its uses those whose definition is not their declaration, which an
     implementation is looked for among; its notes hold the rest as bytes,
     which a question about it reads (opened), or it is opened at its place.
     sidecar is the origins its pickle's names have, which a compile's
     pickle lacks (UnitBasis.load) *)
  type entry={key:string,name:string,file:string,text:string,allow:bool,mode:Source.mode,pickle:string,sidecar:string,facts:fact list,
    types:typeDefinition list,syntax:CompilerSyntax.t option,uses:use list,typing:CompilerNodeTypes.t option,
    printed:printed list,notes:string}
  (* ---- a closed unit's notes, and the store's sidecars (D27) ----

     A unit's facts, uses and types, and the type names its facts printed,
     as bytes, with each string once; and the units whose places their
     origins hold that no reference follows (Env.Held), with the key of
     each one's text then. *)
  val notesFormat=2
  type notes={facts:fact list,uses:use list,types:typeDefinition list,printed:printed list,spans:(string*string) list}
  fun originsIn (uses:use list,types:typeDefinition list)=
    let fun all (Env.Constrained (a,b),found)=all (b,all (a,found))
          | all (origin,found)=origin::found
    in List.foldl (fn ({origin,...}:typeDefinition,found) => all (origin,found))
         (List.foldl (fn ((_,_,_,origin,_),found) => all (origin,found)) [] uses) types end
  (* the units other than own whose places origins hold by span alone *)
  fun spansOf (own,origins)=List.foldl (fn (Env.Named {unit,...},found) =>
      if unit=own orelse unit="" orelse List.exists (fn other => other=unit) found then found else unit::found
    | (_,found) => found) [] origins
  fun encodeNotes ({facts,uses,types,printed,spans}:notes)=
    let val table=ref StringMap.empty val strings=ref [] val count=ref 0
        fun intern text=case StringMap.find (!table,text) of SOME i => i
          | NONE => let val i= !count in table:=StringMap.insert (!table,text,i);strings:=text:: !strings;count:=i+1;i end
        val w=Pickle.writer ()
        fun str text=Pickle.nat (w,intern text)
        fun strs texts=(Pickle.nat (w,length texts);List.app str texts)
        fun span ({file,start,stop}:Source.span)=(str file;Pickle.nat (w,start);Pickle.nat (w,stop))
        fun origin Env.Unknown=Pickle.byte (w,0)
          | origin (Env.Named {unit,kind,name,span=s})=(Pickle.byte (w,1);str unit;str kind;str name;span s)
          | origin (Env.Constrained (a,b))=(Pickle.byte (w,2);origin a;origin b)
          | origin (Env.Held {unit,key,last})=(Pickle.byte (w,3);str unit;str key;origin last)
        fun each f items=(Pickle.nat (w,length items);List.app f items)
        val ()=each (fn {file,start,stop,ty,derived,constructors,arguments,...}:fact =>
          (str file;Pickle.nat (w,start);Pickle.nat (w,stop);str ty;Pickle.bool (w,derived);strs constructors;
           each strs arguments)) facts
        val ()=each (fn (role,(path,name),s,o',derived) => (str role;strs path;str name;span s;origin o';Pickle.bool (w,derived))) uses
        val ()=each (fn {id,origin=o'}:typeDefinition => (str id;origin o')) types
        val ()=each (fn {unit,number,name,arity,eq,shown}:printed =>
          (str unit;Pickle.nat (w,number);str name;Pickle.nat (w,arity);Pickle.bool (w,eq);
           case shown of NONE => Pickle.byte (w,0) | SOME text => (Pickle.byte (w,1);str text))) printed
        val ()=each (fn (unit,key) => (str unit;str key)) spans
        val h=Pickle.writer ()
    in Pickle.nat (h,notesFormat);Pickle.list Pickle.string (h,List.rev (!strings));Pickle.contents h ^ Pickle.contents w end
  fun decodeNotes (unitName,bytes) : notes=
    let val r=Pickle.reader bytes
        val ()=if Pickle.rnat r=notesFormat then () else raise Pickle.Bad "notes of another format"
        val strings=Vector.fromList (Pickle.rlist Pickle.rstring r)
        fun str ()=Vector.sub (strings,Pickle.rnat r) handle Subscript => raise Pickle.Bad "no such string"
        fun each f=List.tabulate (Pickle.rnat r,fn _ => f ())
        fun strs ()=each str
        fun span ()=let val file=str () val start=Pickle.rnat r in {file=file,start=start,stop=Pickle.rnat r}:Source.span end
        fun origin ()=case Pickle.rbyte r of
            0 => Env.Unknown
          | 1 => let val unit=str () val kind=str () val name=str () in Env.Named {unit=unit,kind=kind,name=name,span=span ()} end
          | 2 => let val a=origin () in Env.Constrained (a,origin ()) end
          | 3 => let val unit=str () val key=str () in Env.Held {unit=unit,key=key,last=origin ()} end
          | _ => raise Pickle.Bad "not an origin"
        val facts=each (fn () =>
          let val file=str () val start=Pickle.rnat r val stop=Pickle.rnat r val ty=str () val derived=Pickle.rbool r
              val constructors=strs ()
          in {unit=unitName,file=file,start=start,stop=stop,ty=ty,derived=derived,constructors=constructors,arguments=each strs}:fact end)
        val uses=each (fn () =>
          let val role=str () val path=strs () val name=str () val s=span () val o'=origin ()
          in (role,(path,name),s,o',Pickle.rbool r):use end)
        val types=each (fn () => let val id=str () in {id=id,origin=origin ()}:typeDefinition end)
        val printed=each (fn () =>
          let val unit=str () val number=Pickle.rnat r val name=str () val arity=Pickle.rnat r val eq=Pickle.rbool r
          in {unit=unit,number=number,name=name,arity=arity,eq=eq,shown=case Pickle.rbyte r of 0 => NONE | _ => SOME (str ())}:printed end)
        val spans=each (fn () => let val unit=str () in (unit,str ()) end)
    in if Pickle.atEnd r then {facts=facts,uses=uses,types=types,printed=printed,spans=spans} else raise Pickle.Bad "more than notes" end
  (* Whether facts print where a unit stands, its environment after it (and
     what lies beyond that, where it is a view: Env.beyond), as they printed:
     each type name of theirs printed by the path it had *)
  fun printsSo ((after,outside),printed:printed list)=List.all (fn {unit,number,name,arity,eq,shown} =>
    let val stamp=if unit="" then SOME number else case UnitBasis.loadedAs unit of NONE => NONE
          | SOME u => if number<Vector.sub (#count u,UnitBasis.kTycon) then SOME (Vector.sub (#base u,UnitBasis.kTycon)+number) else NONE
    in case stamp of NONE => false | SOME stamp => Env.qualifiedNameWith outside (after,{name=name,stamp=stamp,arity=arity,eq=eq})=shown end) printed
  (* A sidecar in the store (UnitCache.readSidecar), by the hash of a unit's
     source: the compiler that wrote it, the unit's identity, the names its
     text mentions (CompilerPrelude.usedBy), where it was scanned, the binder of each name its
     elaboration looked up, the origins of its pickle's names, and what a
     closed unit holds (closed: its types, the uses an implementation is
     looked for among, and the places that hold, as notes have them); its
     notes are a part of their own, read where a question asks for them
     (UnitCache.readSidecar). It is a hint: one of another compiler, or whose
     unit is another, or whose usages another binder holds now, is not taken *)
  (* binds and paths: the keys its names are bound by, and what its top-level
     names reach, which a world that loads by need takes it with, its basis
     unread (UnitBasis.lightLoad) *)
  type sidecar={compiler:string,identity:string,mode:string,allow:bool,mentions:string list option,binders:(string*string) list,
    origins:string,closed:string,binds:string list,paths:UnitBasis.unitPath list}
  fun encodeSidecar ({compiler,identity,mode,allow,mentions,binders,origins,closed,binds,paths}:sidecar)=
    let val w=Pickle.writer ()
    in Pickle.string (w,compiler);Pickle.string (w,identity);Pickle.string (w,mode);Pickle.bool (w,allow);
       Pickle.option (Pickle.list Pickle.string) (w,mentions);
       (* each binder once *)
       let val table=ref StringMap.empty val order=ref [] val count=ref 0
           fun index binder=case StringMap.find (!table,binder) of SOME i => i
             | NONE => let val i= !count in table:=StringMap.insert (!table,binder,i);order:=binder:: !order;count:=i+1;i end
           val indices=List.map (fn (key,binder) => (key,index binder)) binders
       in Pickle.list Pickle.string (w,List.rev (!order));
          Pickle.list (fn (w,(key,i)) => (Pickle.string (w,key);Pickle.nat (w,i))) (w,indices) end;
       Pickle.string (w,origins);Pickle.string (w,closed);
       Pickle.list Pickle.string (w,binds);
       Pickle.list (fn (w,(key,name,{own,class,path}:Env.pathKey)) =>
         (Pickle.string (w,key);Pickle.string (w,name);Pickle.bool (w,own);Pickle.nat (w,class);Pickle.list Pickle.string (w,path))) (w,paths);
       Pickle.contents w end
  fun decodeSidecar bytes : sidecar=
    let val r=Pickle.reader bytes
        val compiler=Pickle.rstring r val identity=Pickle.rstring r val mode=Pickle.rstring r val allow=Pickle.rbool r
        val mentions=Pickle.roption (Pickle.rlist Pickle.rstring) r
        val table=Vector.fromList (Pickle.rlist Pickle.rstring r)
        val binders=Pickle.rlist (fn r => let val key=Pickle.rstring r in (key,Vector.sub (table,Pickle.rnat r)) end) r
        val origins=Pickle.rstring r
        val closed=Pickle.rstring r
        val binds=Pickle.rlist Pickle.rstring r
        val paths=Pickle.rlist (fn r => let val key=Pickle.rstring r val name=Pickle.rstring r val own=Pickle.rbool r
            val class=Pickle.rnat r in (key,name,{own=own,class=class,path=Pickle.rlist Pickle.rstring r}:Env.pathKey) end) r
    in if Pickle.atEnd r then {compiler=compiler,identity=identity,mode=mode,allow=allow,mentions=mentions,binders=binders,
         origins=origins,closed=closed,binds=binds,paths=paths}
       else raise Pickle.Bad "more than a sidecar" end
  (* a unit's notes in the store, by the hash of its source, of its identity *)
  fun storedNotes (dir,source,identity)=
    case UnitCache.readSidecar (dir,notesFormat,"notes",source) of NONE => NONE
    | SOME bytes => (let val r=Pickle.reader bytes
                         val written=Pickle.rstring r
                         val notes=Pickle.rstring r
                     in if written=identity andalso Pickle.atEnd r then SOME notes else NONE end)
                    handle Pickle.Bad _ => NONE | Subscript => NONE | Overflow => NONE
  (* A closed unit opened from its notes (bytes), where they hold where it
     stands: its environment after it (after, printing), in which its facts
     print as they did, and the units whose places its occurrences hold by
     span, whose texts' keys keyOf says, as they were *)
  fun fromNotes (entry:entry,bytes,after,keyOf)=
    case (SOME (decodeNotes (#name entry,bytes)) handle Pickle.Bad _ => NONE | Subscript => NONE | Overflow => NONE) of
      NONE => NONE
    | SOME notes =>
        if printsSo (after,#printed notes) andalso List.all (fn (unit,key) => keyOf unit=SOME key) (#spans notes)
        then SOME ({key= #key entry,name= #name entry,file= #file entry,text= #text entry,allow= #allow entry,mode= #mode entry,
               pickle= #pickle entry,sidecar= #sidecar entry,facts= #facts notes,types= #types notes,syntax=NONE,
               uses= #uses notes,typing=NONE,printed= #printed notes,notes=bytes}:entry)
        else NONE
  (* Where a unit's facts print after it (fromNotes): its place's environment
     and what it declared; where its world loads by need, the initial
     environment less what the binders, with the unit's own keys, say, and
     what lies beyond that (Env.beyond) *)
  fun printing (lazy,placeEnv,placeBinders,result:UnitBasis.result,binds)=
    if not lazy then (Env.plus (placeEnv,#delta result),Env.nowhere) else
      let val b=List.foldl (fn (key,m) => StringMap.insert (m,key,#identity (#unit result))) placeBinders binds
      in (UnitBasis.initialLess b,UnitBasis.beyondWith (b,!UnitBasis.pathIndex)) end
  (* a usage's binder, from "IDENTITY FINGERPRINT", the identity a name that
     may have spaces in it *)
  fun binderOfValue value=
    let val fields=String.fields (fn c => c= #" ") value
    in String.concatWith " " (List.take (fields,length fields-1)) end
  (* a usage with its binder by the identity its unit is loaded under *)
  fun canonicalUsage (key,value)=
    let val fields=String.fields (fn c => c= #" ") value
    in (UnitBasis.canonicalKey key,UnitBasis.canonical (binderOfValue value) ^ " " ^ List.last fields) end
  (* the place a unit was reached at; whole: env is the whole environment
     there, where no unit before it was loaded by need *)
  type position={env:Env.env,fixity:Fixity.env,sigs:SigMatch.sigma StringMap.map,funs:Elaborate.funinfo StringMap.map,
    binders:string StringMap.map,overloads:Overload.entry IntMap.map,whole:bool}
  (* What a unit declares, by a key of each definition that outlasts its span:
     its kind and the path to it. defined: each definition now, by key, where
     the unit has been elaborated since it was loaded, or worked out from
     what was loaded when first asked. keys: each definition as a client found
     it, by where it was, worked out from what was loaded when first asked. *)
  (* What a unit loaded in a world has: what its load gave and the place it was
     reached at. A walk that takes the unit out of the session takes this away,
     in every state that shares it, so that a walk's new units do not stand
     beside the old. *)
  (* light: loaded by need, its basis not read until a view wants it
     (UnitBasis.lightLoad), whose result holds no environment *)
  type live={result:UnitBasis.result,bindings:UnitBasis.bindings,position:position,light:bool}
  (* binds: the keys its names are bound by, and paths: what its top-level
     names reach (UnitBasis.unitPaths), which a load by need takes again
     without its basis; none where the world loads every basis *)
  type kept={entry:entry,identity:string,live:live option ref,usages:(string*string) list,index:int,
    defined:Env.origin StringMap.map option ref,keys:string StringMap.map option ref,
    binds:string list,paths:UnitBasis.unitPath list}
  (* What a check leaves. complete: the last walk went through to the end, so
     that every place stands. stamps: of the files the libraries were read
     from. paths: of the units no longer in a session, which a pickle that
     holds by its usages still names *)
  type state={serial:int,kept:kept StringMap.map,order:string list,opens:string list,complete:bool,
    planned:(CompilerProject.step list*string list*string option*string option) option,
    prelude:CompilerPrelude.plan option,units:string list,libraryNames:string StringMap.map,
    libraries:(BasisManifest.entry*string) list,stamps:(string*string) list,
    names:(Source.mode*string*unit StringMap.map) StringMap.map,paths:(int*int*string) list StringMap.map}
  val noState:state={serial=0,kept=StringMap.empty,order=[],opens=[],complete=false,planned=NONE,prelude=NONE,units=[],
    libraryNames=StringMap.empty,libraries=[],stamps=[],names=StringMap.empty,paths=StringMap.empty}
  (* How a check went. walked: from the start, in place of a change at its
     place. rebound: units taken as they stood; loaded: taken again from their
     pickles; cutoff: elaborated to the identity they had; broken: a usage
     said no; stored: taken from a compile's entries in the store, with
     their sidecars; byNeed: of those stored or loaded, those taken without
     their basis (UnitBasis.lightLoad) *)
  type route={walked:bool,rebound:int,loaded:int,cutoff:int,broken:int,stored:int,byNeed:int}
  (* entries: what the check reached, by name, order its names; attempted: the
     syntax of the unit that failed; opened: a unit opened for a question *)
  type snapshot={diagnostics:CompilerSession.diagnostic list,reused:int,checked:int,dependencies:source list,
    candidates:candidate list,role:string,fields:(string*string) list,application:application option,
    state:state,entries:kept StringMap.map,order:string list,attempted:(string*CompilerSyntax.t) option,
    prelude:CompilerPrelude.plan,units:string list,opened:entry option,route:route}
  type observation={phase:string,file:string,checked:int,reused:int,items:int}
  (* a compiler state whose units stay loaded; base: its tables as a walk
     begins; lazy: whether its units are loaded by need (docs/compiler-analysis.md,
     Loading by need) *)
  datatype world=World of {owner:CompilerState.session,
    base:(SigMatch.sigma StringMap.map*Elaborate.funinfo StringMap.map*Overload.entry IntMap.map) option ref,lazy:bool}
  (* What the sessions that share have left of the libraries' units, by name,
     with the configuration they were elaborated in: a unit of a library is
     the same unit in two builds over it (D3), and is taken in a session that
     has not held it as a walk takes a unit, where its usages hold (D26, two
     builds over one library). Each is kept without its place, which is a
     world's. A pool is its sharers' to hold, not this structure's: the
     sessions that share may belong to several compilers *)
  type pool=(CompilerSession.config*kept) StringMap.map ref
  fun pool () : pool=ref StringMap.empty
  (* doomed: an exception left the world's tables half written. shares:
     the pool a library's units are taken from and left in, if any *)
  (* store: the directory of the store a check takes a compile's entries and
     the sidecars from, and writes sidecars to; NONE, none *)
  (* lazy: whether a world loads its units by need, which goes off for good
     where a unit read outside its view (UnitBasis.Unviewable) *)
  datatype session=Session of {state:state ref,world:world option ref,config:CompilerSession.config,closed:bool ref,
    observer:(observation->unit) option ref,focus:unit StringMap.map option ref,doomed:bool ref,walks:int ref,shares:pool option ref,
    store:string option ref,lazy:bool ref}
  exception Cancelled
  (* a query has what it asked for once its unit is elaborated *)
  exception Answered
  (* an identity moved where nothing was to walk *)
  exception NeedWalk
  (* A unit that does not check, with every error of it that is independent of
     the others, as a compile reports them (Elaborate.recover; docs/units.md,
     Errors), and what it holds where it was elaborated past them, which a
     question about the unit asks: the walk stops after it *)
  exception UnitFailed of entry option * CompilerSession.diagnostic list
  (* What a question about a unit wants of it: Probe, what is visible at a
     place in it, elaborated as far as that; Open, its facts, uses and types,
     from its notes where they hold; Whole, its syntax and typing too *)
  datatype opening=Probe | Open | Whole
  (* the errors the unit being elaborated has reported and gone on past *)
  fun keptErrors ()=List.mapPartial (fn (severity,span,message) =>
    if severity="error" then SOME (CompilerSession.sourceError ("error",span,message)) else NONE) (List.rev (!Error.kept))
  fun new config=Session {state=ref noState,world=ref NONE,config=config,closed=ref false,observer=ref NONE,focus=ref NONE,doomed=ref false,
    walks=ref 0,shares=ref NONE,store=ref NONE,lazy=ref true}
  fun dropWorld (Session {world,...})=(Option.app (fn World {owner,...} => CompilerState.close owner) (!world);world:=NONE)
  fun close (session as Session {closed,state,...})=(closed:=true;state:=noState;dropWorld session)
  (* a state whose units must load again *)
  fun unplaced (saved:state,serial):state=
    {serial=serial,kept= #kept saved,order= #order saved,opens= #opens saved,complete=false,planned= #planned saved,
     prelude= #prelude saved,units= #units saved,libraryNames= #libraryNames saved,libraries= #libraries saved,
     stamps= #stamps saved,names= #names saved,paths= #paths saved}
  (* a session of its own over a state: what a query of an old snapshot, or
     one whose context has closed, walks through; nothing in it is to be kept open *)
  fun over (state,config)=Session {state=ref (unplaced (state,#serial state)),world=ref NONE,config=config,closed=ref false,
    observer=ref NONE,focus=ref (SOME StringMap.empty),doomed=ref false,walks=ref 0,shares=ref NONE,store=ref NONE,lazy=ref true}
  (* a state taken back: this session's earlier one *)
  fun restore (session as Session {state=current,...},saved:state)=
    (dropWorld session;current:=unplaced (saved,#serial (!current)+1))
  (* which files stay open; NONE, all of them *)
  fun focus (Session {focus,state,...},files)=
    (case (files,!focus) of
       (NONE,SOME _) => state:=unplaced (!state,#serial (!state)+1)  (* a library's closed units, which only a walk opens *)
     | _ => ();
     focus:=Option.map (List.foldl (fn (file,all) => StringMap.insert (all,file,())) StringMap.empty) files)
  (* a unit closed: its notes made, where it has none, with the key of each
     unit's text whose places its origins hold, keyOf (none, "", which no
     text has, and a question then opens the unit at its place) *)
  fun notesRecord keyOf (entry:entry) : notes={facts= #facts entry,uses= #uses entry,types= #types entry,printed= #printed entry,
    spans=List.map (fn unit => (unit,getOpt (keyOf unit,""))) (spansOf (#name entry,originsIn (#uses entry,#types entry)))}
  (* none of a unit with no syntax: one taken from the store, whose notes
     are the store's (notesOf') *)
  fun notesOf keyOf (entry:entry)=if #notes entry<>"" orelse not (isSome (#syntax entry)) then #notes entry
    else encodeNotes (notesRecord keyOf entry)
  (* what a closed unit holds decoded, as notes: no facts, of its uses
     those an implementation is looked for among, its types *)
  fun implementations (uses:use list)=List.filter (fn (_,_,_,origin,_) => Env.primary origin<>Env.declaration origin) uses
  fun closedOf ({uses,types,spans,...}:notes)=
    encodeNotes {facts=[],uses=implementations uses,types=types,printed=[],spans=spans}
  fun closedEntry keyOf (entry:entry):entry=
    {key= #key entry,name= #name entry,file= #file entry,text= #text entry,allow= #allow entry,mode= #mode entry,pickle= #pickle entry,
     sidecar= #sidecar entry,facts=[],types= #types entry,syntax=NONE,typing=NONE,
     uses=implementations (#uses entry),printed=[],notes=notesOf keyOf entry}
  fun isOpen (entry:entry)=isSome (#syntax entry)
  (* every origin of what a unit declares, by its key *)
  fun definitions (delta:Env.env,sigs:(string*SigMatch.sigma) list,funs:(string*Elaborate.funinfo) list) =
    let val found=ref []
        fun note (key,origin)=case origin of Env.Unknown => () | _ => found:=(key,origin):: !found
        fun walk (prefix,Env.Env {strs,origins,...})=
          (StringMap.appi (fn (key,origin) => note (prefix ^ key,origin)) origins;
           StringMap.appi (fn (name,inner) => walk (prefix ^ name ^ ".",inner)) strs)
        fun sigma (prefix,{env,...}:SigMatch.sigma)=walk (prefix,env)
        val ()=walk ("",delta)
        val ()=List.app (fn (name,sg:SigMatch.sigma) => (note ("g " ^ name,#origin sg);sigma ("sig:" ^ name ^ ".",sg))) sigs
        val ()=List.app (fn (name,Elaborate.FunInfo {binding,paramSig,summary,...}) =>
          (note ("f " ^ name,binding);sigma ("par:" ^ name ^ ".",paramSig);walk ("fun:" ^ name ^ ".",#result summary))) funs
    in !found end
  fun leafKey origin=case origin of
      Env.Named {kind,name,span={file,start,stop},...} =>
        SOME (kind ^ "\000" ^ name ^ "\000" ^ file ^ "\000" ^ Int.toString start ^ "\000" ^ Int.toString stop)
    | _ => NONE
  (* the definitions of a kept unit as they were loaded; of one loaded by
     need none, but where its world is entered (inside), which loads it *)
  fun loadedDefinitions' (k:kept,inside)=case !(#live k) of NONE => []
    | SOME {result,bindings,light,...} =>
        if not light then definitions (#delta result,#sigs bindings,#funs bindings)
        else if not inside then []
        else case UnitBasis.materialisedOf (#identity k)
                    handle UnitBasis.Missing why => raise UnitBasis.Unviewable ("a basis loaded by need names " ^ why)
                         | Pickle.Bad why => raise UnitBasis.Unviewable ("a basis loaded by need: " ^ why) of
          SOME {delta,sigs,funs} => definitions (delta,sigs,funs)
        | NONE => []
  fun loadedDefinitions k=loadedDefinitions' (k,false)
  fun isLight (k:kept)=case !(#live k) of SOME {light,...} => light | NONE => false
  (* in its world: what a client elaborated there holds (hold) *)
  fun keysOf (k:kept)=case !(#keys k) of SOME keys => keys | NONE =>
    let fun leaves (key,origin,all)=case origin of
            Env.Constrained (a,b) => leaves (key,b,leaves (key,a,all))
          | _ => case leafKey origin of NONE => all | SOME leaf =>
              if StringMap.member (all,leaf) then all else StringMap.insert (all,leaf,key)
        val keys=List.foldr (fn ((key,origin),all) => leaves (key,origin,all)) StringMap.empty (loadedDefinitions' (k,true))
    in #keys k:=SOME keys;keys end
  (* An origin that names another unit, made a reference to that definition.
     find: a unit by its name. *)
  fun hold (find,own:string) origin=case origin of
      Env.Constrained (a,b) => Env.Constrained (hold (find,own) a,hold (find,own) b)
    | Env.Named {unit,...} => if unit=own then origin else
        (case find unit of NONE => origin | SOME k =>
           case Option.mapPartial (fn leaf => StringMap.find (keysOf k,leaf)) (leafKey origin) of
             SOME key => Env.Held {unit=unit,key=key,last=origin} | NONE => origin)
    | _ => origin
  (* what a unit loaded by need defines is known where a client elaborated
     in its world asked (keysOf), or where it was elaborated; else a
     reference to it is taken as it was (resolve, last), and none is kept *)
  fun definedBy (find,k:kept)=case !(#defined k) of SOME all => all | NONE =>
    let val own= #name (#entry k)
        val all=List.foldl (fn ((key,origin),all) => StringMap.insert (all,key,hold (find,own) origin)) StringMap.empty
          (loadedDefinitions k)
    in if isLight k then () else #defined k:=SOME all;all end
  (* An origin as it stands in a state, a reference followed to where its
     definition is now: what a fresh analysis would say *)
  fun resolve (find:string->kept option) origin=case origin of
      Env.Constrained (a,b) => Env.Constrained (resolve find a,resolve find b)
    | Env.Held {unit,key,last} =>
        (case find unit of NONE => last | SOME k =>
           case StringMap.find (definedBy (find,k),key) of SOME now => resolve find now | NONE => last)
    | _ => origin
  fun identityOf (k:kept)= #identity k
  fun liveOf (k:kept)=case !(#live k) of SOME live => live | NONE => raise Fail "a unit not loaded taken as loaded"
  (* the signatures or functors a unit declared, in the order it declared them,
     the last of each name, from its names newest first *)
  fun declared (names,table)=List.mapPartial (fn n => Option.map (fn value => (n,value)) (StringMap.find (table,n)))
    (List.foldl (fn (n,kept) => if List.exists (fn other => other=n) kept then kept else n::kept) [] names)
  fun sameSteps (a:CompilerProject.step list,b:CompilerProject.step list)=
    let fun same (CompilerProject.SUnit x,CompilerProject.SUnit y)=x=y
          | same (CompilerProject.SLibrary (x,a),CompilerProject.SLibrary (y,b))=x=y andalso sameSteps (a,b)
          | same (CompilerProject.SUse (x,a),CompilerProject.SUse (y,b))=x=y andalso sameSteps (a,b)
          | same (CompilerProject.SImplements (x,a),CompilerProject.SImplements (y,b))=x=y andalso sameSteps (a,b)
          | same _=false
        fun all ([],[])=true | all (x::xs,y::ys)=same (x,y) andalso all (xs,ys) | all _=false
    in all (a,b) end
  (* A file's stamp holds where it is older than its time can tell. *)
  fun stampOf file=(Time.toString (OS.FileSys.modTime file) ^ ":" ^ Position.toString (OS.FileSys.fileSize file))
    handle OS.SysErr _ => "absent"
  fun settled file=(Time.< (Time.+ (OS.FileSys.modTime file,Time.fromSeconds 3),Time.now ())) handle OS.SysErr _ => true
  (* the world of a session, entered *)
  fun inWorld (session as Session {world,doomed,...},action) =
    let val current=case !world of SOME current => current | NONE =>
          let val Session {lazy=lazySetting,...}=session
            val made=World {owner=CompilerState.session (),base=ref NONE,lazy= !lazySetting}
          in world:=SOME made;made end
        val World {owner,base,lazy}=current
        fun work ()=
          (Pass.lintDefault:=1;
           (* what elaboration reads of a unit, and no more (D27): a compile's
              basis and an analysis's load alike where their static layers do *)
           UnitBasis.staticOnly:=true;UnitCache.needMid:=false;
           (* a type's path where the env given is the whole: none beyond *)
           Env.beyond:=Env.nowhere;
           if isSome (!base) then () else
             (UnitBasis.startSession ();UnitBasis.startLazy lazy;UnitBasis.indexPaths:=lazy;
              base:=SOME (!Elaborate.sigs,!Elaborate.funs,!Overload.table));
           let val (sigs,funs,overloads)=valOf (!base) in action (sigs,funs,overloads,lazy) end)
        fun left ()=if !doomed then (doomed:=false;dropWorld session) else ()
        val result=CompilerState.withSession (owner,work) handle error => (left ();raise error)
    in left ();result end
  (* A compaction: the world goes, with whatever its tables have kept of units
     long replaced, and the next check loads the units into a new one. It also
     forgets the paths of the identities no entry names. So it is done now and
     then, by what has been walked: a walk costs a load of the units after a
     change, and this a load of them all. *)
  val walksToCompact=256
  fun compact (session as Session {state,walks,world,...})=
    let val saved= !state
        (* by the identities the units are loaded under (UnitBasis.alias),
           where the world knows them *)
        fun gather canonical=StringMap.foldl (fn (k:kept,all) => List.foldl (fn (identity,all) => StringMap.insert (all,canonical identity,()))
          all (UnitBasis.namedBy (#pickle (#entry k)) handle Pickle.Bad _ => [])) StringMap.empty (#kept saved)
        val named=case !world of NONE => gather (fn identity => identity) | SOME _ => inWorld (session,fn _ => gather UnitBasis.canonical)
    in walks:=0;restore (session,{serial= #serial saved,kept= #kept saved,order= #order saved,opens= #opens saved,complete=false,
         planned= #planned saved,prelude= #prelude saved,units= #units saved,libraryNames= #libraryNames saved,
         libraries= #libraries saved,stamps= #stamps saved,names= #names saved,
         paths=StringMap.filteri (fn (identity,_) => StringMap.member (named,identity)) (#paths saved)}) end
  (* units: the logical name of each of sources, as rune gives them
     (Workspace), its libraries' first, so that a unit is the same name in
     analysis and in a build. building: the build file checked, which a
     library's header may name a friend (CompilerPrelude.select). view: the
     build's view of the Basis Library, if it has one (D12), which the
     selection takes as a compile does. opening: what is wanted of the
     unit query names. *)
  fun checkWorld (session as Session {state=saved,world,config,closed,observer,focus=focused,doomed,walks,shares,store=storeSetting,...},scope:Workspace.scope,sources:source list,steps,extraLibraries,cancelled,query:scopeQuery option,
                 frozen:source list,frozenPlan:CompilerPrelude.plan option,building:string option,view:string option,opening:opening) : snapshot = inWorld (session,fn (baseSigs,baseFuns,baseOverloads,lazyWorld) =>
    let val {lib,libraries,target,allowPrim,...}=config
        val old= !saved
        (* each input's names, scanned where its text is new (scan) *)
        val names=ref (#names old)
        val mentions=ref false
        val storeDir= !storeSetting
        (* the configurations of its entries whose static layers this
           analysis's are (UnitCache.configurationsFor), once asked for *)
        val configs=ref StringMap.empty : string list StringMap.map ref
        fun configsOf dir=case StringMap.find (!configs,dir) of SOME found => found | NONE =>
          let val found=UnitCache.configurationsFor dir in configs:=StringMap.insert (!configs,dir,found);found end
        (* a compile's entry of a key: in the store, then in its layers, the
           frozen libraries (UnitCache.layers), which are only read *)
        fun entryFor (dir,k)=case UnitCache.findStatic {overlay=true} (dir,configsOf dir,k) of
            SOME found => SOME found
          | NONE => List.foldl (fn (layer,found) => case found of SOME _ => found
              | NONE => UnitCache.findStatic {overlay=false} (layer,configsOf layer,k)) NONE (UnitCache.layers ())
        val ()=CompilerSettings.target:=target
        val ()=CompilerSettings.libDir:=lib
        val ()=BasisManifest.roots:= #libraries scope
        val ()=CompilerSession.language config
        val scopeEnv=ref NONE : (int*Env.env*SigMatch.sigma StringMap.map*Elaborate.funinfo StringMap.map) option ref
        val application=ref NONE : (int*application) option ref
        val role=ref "unknown"
        val queriedSyntax=ref [] : Ast.program ref
        fun classify (syntax,offset) =
          let fun category kind=if kind="ESelect" then "field" else if String.isPrefix "Ty" kind then "type"
                else if String.isPrefix "P" kind then "pattern"
                else if String.isPrefix "E" kind andalso kind<>"ExnDecl" andalso kind<>"ExnRepl" then "expression"
                else if String.isPrefix "Str" kind orelse kind="DOpen" then "structure"
                else if String.isPrefix "Sig" kind orelse String.isPrefix "Spec" kind then "signature" else "declaration"
              fun choose ((kind,span:Source.span,_),old)=
                if #file span="" orelse offset< #start span orelse offset> #stop span then old else
                  let val width= #stop span- #start span
                  in case old of SOME (prior,_) => if prior<width then old else SOME (width,category kind)
                   | NONE => SOME (width,category kind) end
          in case List.foldl choose NONE (SyntaxAst.shape syntax) of NONE => "unknown" | SOME (_,role) => role end
        val ()=Env.observeExpression:=(fn (expression,_) => case (query,expression) of
          (SOME query,Ast.EApp (function,argument,span, _)) =>
            let val argumentSpan=Ast.spanOfExp argument
                fun head (Ast.EVar ((path,name),_,_, _),n)=SOME (path,name,n)
                  | head (Ast.EApp (function,_,_, _),n)=head (function,n+1)
                  | head (Ast.ETyped (function,_,_, _),n)=head (function,n)
                  | head _=NONE
                fun parameter ([],index)=Int.max (0,index-1)
                  | parameter (value::rest,index)=if #offset query<= #stop (Ast.spanOfExp value) then index
                      else parameter (rest,index+1)
                val width= #stop span- #start span
            in if !Env.currentUnit<> #unit query orelse #file span<> #file query orelse
                  #offset query< #start argumentSpan orelse #offset query> #stop argumentSpan then () else
                 case head (function,0) of NONE => () | SOME (path,name,index) =>
                   (case !application of SOME (prior,_) => if prior<=width then () else
                      application:=SOME (width,{path=path,name=name,argument=index,
                        parameter=case argument of Ast.ETuple (values,_, _) => parameter (values,0) | _ => 0})
                    | NONE => application:=SOME (width,{path=path,name=name,argument=index,
                        parameter=case argument of Ast.ETuple (values,_, _) => parameter (values,0) | _ => 0})) end
        | _ => ())
        val ()=Env.observeScope:=(fn (span:Source.span,env) => case query of NONE => () | SOME query =>
          if !Env.currentUnit<> #unit query orelse #file span<> #file query orelse #start span> #offset query orelse #stop span< #offset query then () else
            let val width= #stop span- #start span
            in case !scopeEnv of SOME (old,_,_,_) => if old<=width then () else scopeEnv:=SOME (width,env,!Elaborate.sigs,!Elaborate.funs)
             | NONE => scopeEnv:=SOME (width,env,!Elaborate.sigs,!Elaborate.funs) end)
        fun poll ()=if !closed then raise CompilerSession.Closed else if cancelled () then raise Cancelled else ()
        val ()=poll ()
        (* an analysis makes no code: no copy of a functor's body (D15); and
           it goes past a declaration that fails, as a compile does *)
        val ()=(Error.keep:=true;Error.silent:=true;Error.kept:=[];Error.errors:=0;Elaborate.recover:=true;Elaborate.makesCode:=false)
        (* what the editor's types read of each unit, kept (CompilerNodeTypes) *)
        val ()=Elaborate.lintRecords:=true
        val env=ref Env.initial
        val fixity=ref Fixity.initial
        val staged=ref [] : string list ref
        val unitUses=ref []
        val attempted=ref NONE : (string*CompilerSyntax.t) option ref
        val openedEntry=ref NONE : entry option ref
        val ()=Env.tracking:=true
        val ()=Env.observe:=(fn event => unitUses:=event :: !unitUses)
        val reused=ref 0
        val checked=ref 0
        fun observe phase file items=Option.app(fn f=>f {phase=phase,file=file,checked= !checked,reused= !reused,items=items})(!observer)
        val ()=observe "analysis-start" "" (length sources)
        val samePlan=case #planned old of NONE => false
          | SOME (priorSteps,priorLibraries,_,_) => priorLibraries=extraLibraries andalso sameSteps (priorSteps,steps)
        (* what the libraries are chosen by besides: the build checked, whose
           friends see more, and its view of the Basis Library *)
        val sameBuilding=case #planned old of NONE => false
          | SOME (_,_,priorBuilding,priorView) => priorBuilding=building andalso priorView=view
        val ()=Source.overlays:=StringMap.fromList (List.map (fn source => (#file source,#text source)) (frozen @ sources))
        fun replacement (beforeText,afterText) =
          let val beforeSize=size beforeText
              val afterSize=size afterText
              fun prefix i=if i<beforeSize andalso i<afterSize andalso String.sub (beforeText,i)=String.sub (afterText,i) then prefix (i+1) else i
              val start=prefix 0
              fun suffix k=if k<beforeSize-start andalso k<afterSize-start andalso
                String.sub (beforeText,beforeSize-k-1)=String.sub (afterText,afterSize-k-1) then suffix (k+1) else k
              val suffix=suffix 0
          in {start=start,stop=beforeSize-suffix,text=String.substring (afterText,start,afterSize-suffix-start)} end
        (* what this check has done to the state, each unit at most once *)
        val next=ref StringMap.empty : kept StringMap.map ref
        val paths=ref (#paths old)
        (* the units from here on are out of the session; moved: because an
           identity moved, rather than for want of a session *)
        val dirty=ref false
        val moved=ref false
        val walked=ref 0
        val rebound=ref 0
        val loaded=ref 0
        val cutoff=ref 0
        val broken=ref 0
        val stored=ref 0
        val byNeed=ref 0
        (* in a load, where an exception leaves the tables half written *)
        val exposed=ref false
        fun cut index =
          let val leaving=StringMap.foldl (fn (k:kept,all) =>
                if #index k>=index andalso UnitBasis.isLoaded (identityOf k) then k::all else all) [] (#kept old)
              val gone=List.map identityOf leaving
              val ()=List.app (fn k:kept => #live k:=NONE) leaving
              val ()=exposed:=true
              val out=UnitBasis.truncate gone
              (* an identity's paths are its own: a unit loaded by need,
                 whose names no table has, leaves those it had standing *)
              fun keep (identity,kept)=if null kept andalso StringMap.member (!paths,identity) then ()
                else paths:=StringMap.insert (!paths,identity,kept)
          in exposed:=false;List.app keep out;dirty:=true end
        (* whether env is the whole environment: until a unit is loaded by
           need, from the start of a walk (as a compile's warm path gives no
           view until then) *)
        val envWhole=ref true
        fun place ():position={env= !env,fixity= !fixity,sigs= !Elaborate.sigs,funs= !Elaborate.funs,binders= !UnitBasis.binders,
          overloads= !Overload.table,whole= !envWhole}
        fun setPlace ({env=e,fixity=f,sigs,funs,binders,overloads,whole}:position)=
          (env:=e;fixity:=f;Elaborate.sigs:=sigs;Elaborate.funs:=funs;UnitBasis.binders:=binders;Overload.table:=overloads;
           envWhole:=whole)
        fun isFocused file=case !focused of NONE => true | SOME files => StringMap.member (files,file)
        fun priorOf name=case StringMap.find (!next,name) of SOME k => SOME k | NONE => StringMap.find (#kept old,name)
        (* the key of a unit's text, by its name *)
        fun keyOf name=Option.map (fn k:kept => #key (#entry k)) (priorOf name)
        fun spanHolds (unit,key)=keyOf unit=SOME key
        val sourceHash=UnitCache.sourceHash
        fun keyFor (name,allow,mode,source)=Pickle.hash (name ^ ":" ^ Bool.toString allow ^ ":" ^ Source.modeName mode ^ ":" ^ source)
        (* A unit's sidecar into the store, where its text is its file's: a
           unit is written under its saved text alone, never under a buffer
           an editor has not saved (D27) *)
        fun onDisk (file,text)=(UnitCache.readFile file=text) handle IO.Io _ => false | OS.SysErr _ => false
        (* the hash of an input's text, once a check *)
        val hashes=ref StringMap.empty : (string*string) StringMap.map ref
        fun hashOf (file,text)=case StringMap.find (!hashes,file) of
            SOME (known,hash) => if known=text then hash else rehash (file,text)
          | NONE => rehash (file,text)
        and rehash (file,text)=let val hash=sourceHash text in hashes:=StringMap.insert (!hashes,file,(text,hash));hash end
        (* the store's sidecar of a source, once a check: NONE, none, or one
           that cannot be read or is another compiler's, a hint no answer is
           taken from (D27) *)
        val sides=ref StringMap.empty : sidecar option StringMap.map ref
        fun sideOf (dir,source)=case StringMap.find (!sides,source) of SOME found => found | NONE =>
          let val found=case UnitCache.readSidecar (dir,notesFormat,"head",source) of NONE => NONE
                | SOME bytes => (SOME (decodeSidecar bytes) handle Pickle.Bad _ => NONE | Subscript => NONE | Overflow => NONE)
          in sides:=StringMap.insert (!sides,source,found);found end
        fun keepSidecar (entry:entry,identity,usages,origins,binds,paths)=case storeDir of NONE => () | SOME dir =>
            let val notes=notesRecord keyOf entry
                val source=hashOf (#file entry,#text entry)
                val w=Pickle.writer ()
                val ()=(Pickle.string (w,identity);Pickle.string (w,if #notes entry<>"" then #notes entry else encodeNotes notes))
            in UnitCache.storeSidecar (dir,notesFormat,"notes",source,Pickle.contents w);
               UnitCache.storeSidecar (dir,notesFormat,"head",source,
                 encodeSidecar {compiler=Config.identity,identity=identity,mode=Source.modeName (#mode entry),allow= #allow entry,
                   mentions=case StringMap.find (!names,#file entry) of
                       SOME (mode,text,found) => if mode= #mode entry andalso text= #text entry then SOME (StringMap.listKeys found) else NONE
                     | NONE => NONE,
                   binders=List.map (fn (key,value) => (key,binderOfValue value)) usages,origins=origins,
                   closed=closedOf notes,binds=binds,paths=paths}) end
        (* In a world that loads by need (lazyWorld): the environment between
           units is the initial one, the binders saying the rest; a unit is
           elaborated in a view of what its text names (UnitBasis.lazyView),
           and one taken whole or from its pickle is loaded by need where it
           holds by its binders (UnitBasis.lightLoad) *)
        val lazyBase=Env.initial
        val noBindings={sigs=[],funs=[],overloads=[]}:UnitBasis.bindings
        (* A unit that registers an overloading, which every unit after it
           reads by no name, is loaded whole at its place, as where every
           basis is loaded, so that a walk enters its registrations again
           (rebind), and only those of the units before a place stand there *)
        fun registers binds=List.exists (fn key => String.isPrefix "o " key) binds
        (* a basis loaded by need that does not load is the end of loading
           by need, as a view's name not there is (UnitBasis.Unviewable) *)
        fun needing f=f () handle UnitBasis.Missing why => raise UnitBasis.Unviewable ("a basis loaded by need names " ^ why)
                                | Pickle.Bad why => raise UnitBasis.Unviewable ("a basis loaded by need: " ^ why)
        (* what a basis names, loaded, before it is loaded whole *)
        fun materialiseNamed pickle=
          if lazyWorld then needing (fn () => UnitBasis.materialiseNamed (UnitBasis.namedBy pickle handle Pickle.Bad _ => [])) else ()
        (* the names a unit's text has, which its view takes *)
        val viewed=ref StringMap.empty : (string*unit StringMap.map) StringMap.map ref
        fun viewNames ({file,text,mode}:source)=case StringMap.find (!viewed,file) of
            SOME (known,found) => if known=text then found else viewNamesOf (file,text,mode)
          | NONE => viewNamesOf (file,text,mode)
        and viewNamesOf (file,text,mode)=
          let val (lexemes,_,_)=CompilerSyntax.lexical {file=file,text=text,mode=mode,previous=NONE,change=NONE}
              val found=BasisManifest.namesOf (CompilerSyntax.tokens lexemes file,StringMap.empty)
          in viewed:=StringMap.insert (!viewed,file,(text,found));found end
        (* the first usage that does not hold here: by a view of the names of
           those that do not hold by their binder alone, where the world loads
           by need *)
        fun brokenHere usages=
          if not lazyWorld orelse !envWhole orelse UnitBasis.exact usages then UnitBasis.broken usages else
            let val loose=List.filter (fn u => not (UnitBasis.exact [u])) usages
            in UnitBasis.position (needing (fn () => UnitBasis.lazyView (baseSigs,baseFuns,SOME (UnitBasis.namesOfKeys (List.map #1 loose)))),
                 !fixity);
               UnitBasis.broken usages end
        (* a unit's notes: what it holds, else the store's, of its identity *)
        fun notesOf' (entry:entry,identity)=if #notes entry<>"" then SOME (#notes entry) else
          case storeDir of NONE => NONE | SOME dir => storedNotes (dir,hashOf (#file entry,#text entry),identity)
        (* A unit no session has held, from the store: a compile's entry whose
           usages hold here, by their binders, loaded as an analysis loads
           (UnitBasis.staticOnly) under its static identity, with its
           sidecar's origins, uses and types, and its notes; NONE where either
           is not there or does not hold. found: the entry's identity and its
           static one, where there is an entry, which a unit elaborated here
           to the same static identity is known by too (UnitBasis.alias) *)
        (* Each compile's entry of a key whose static layer is the one a unit
           elaborated here has: the same unit to an analysis, by which a
           compile's entries after it name it (UnitBasis.alias) *)
        (* a unit loaded from a pickle is known by the identity in its header too *)
        fun aliasOwn (pickle,identity)=
          (let val {uname,digest,...}=UnitBasis.header pickle in UnitBasis.alias (uname ^ "@" ^ digest,identity) end)
          handle Pickle.Bad _ => ()
        fun aliasAll (dir,k,identity)=
          List.app (fn d => List.app (fn config => List.app (fn e:UnitCache.entry =>
              let val {uname,digest,static,...}=UnitBasis.header (#pickle e)
              in if uname ^ "@" ^ static=identity then UnitBasis.alias (uname ^ "@" ^ digest,identity) else () end
              handle Pickle.Bad _ => ()) (UnitCache.entriesAt (d,config,k))) (configsOf d)) (dir::UnitCache.layers ())
        fun storedUnit (dir,{file,text,mode}:source,name,allow,here,(k,source)) =
          let (* why not, as an observation (store-missed): 1 no entry holds,
                 2 no sidecar, 3 another compiler's, 4 another unit's, 5 a
                 binder is another, 6 a place is another, 7 it did not load *)
              fun missed why=(observe "store-missed" file why;NONE)
          in case entryFor (dir,k) of NONE => missed 1 | SOME batch =>
             let val {uname,digest,static,...}=UnitBasis.header (#pickle batch)
                 val identity=name ^ "@" ^ static
             in if uname<>name then missed 4 else
                case sideOf (dir,source) of NONE => missed 2 | SOME side =>
                let val notes=decodeNotes (name,#closed side)
                in if #compiler side<>Config.identity then missed 3
                   else if #identity side<>identity orelse #mode side<>Source.modeName mode orelse #allow side<>allow then missed 4
                   else if not (List.all (fn (key,binder) => UnitBasis.binderOfKey (UnitBasis.canonicalKey key)=binder) (#binders side)) then missed 5
                   else if not (List.all spanHolds (#spans notes)) then missed 6
                   else
                     let val at=UnitBasis.counters ()
                         val light=lazyWorld andalso not (null (#binds side)) andalso not (registers (#binds side))
                         val ()=exposed:=true
                         val result=SOME (if light then UnitBasis.lightLoad ({pickle= #pickle batch,sidecar= #origins side,file=file,at=at},
                                            identity,#binds side,#paths side)
                                          else (materialiseNamed (#pickle batch);
                                                UnitBasis.loadKnown ({pickle= #pickle batch,sidecar= #origins side,file=file,at=at},SOME identity,[])))
                           handle UnitBasis.Missing _ => (UnitBasis.abandon at;NONE) | Pickle.Bad _ => (UnitBasis.abandon at;NONE)
                     in exposed:=false;
                        case result of NONE => missed 7 | SOME result =>
                          (UnitBasis.alias (uname ^ "@" ^ digest,identity);if light then byNeed:= !byNeed+1 else ();
                           SOME ({key=keyFor (name,allow,mode,source),name=name,file=file,text=text,allow=allow,mode=mode,pickle= #pickle batch,
                                  sidecar= #origins side,facts=[],types= #types notes,syntax=NONE,typing=NONE,
                                  uses= #uses notes,printed=[],notes=""}:entry,
                                 identity,ref (SOME {result=result,bindings=if light then noBindings else !UnitBasis.lastBindings,position=here,light=light}),
                                 List.map canonicalUsage (List.filter (fn (key,_) => not (String.isPrefix "inl " key orelse
                                   String.isPrefix "inlv " key)) (#usages batch)),ref NONE,ref NONE,
                                 if not lazyWorld then [] else if light then #binds side else UnitBasis.bindKeys result,
                                 if not lazyWorld then [] else if light then #paths side else getOpt (UnitBasis.pathsOfUnit identity,[]),
                                 light)) end end
                handle Pickle.Bad _ => NONE | Subscript => NONE | Overflow => NONE end end
          handle Pickle.Bad _ => NONE
        (* What the units after a unit whose identity is about to move used of
           it, in this analysis's terms. A unit taken from a compile's entry
           holds its usages by the compile's fingerprints, which an analysis's
           never equal, so each unit that used one whose identity moves would
           be elaborated again, though what it used be the same. They are
           worked out where the unit still stands, before the cut that takes
           it out, as an analysis that elaborated them would have recorded
           them (restated, usagesOf) *)
        val restated=ref StringMap.empty : (string*string) list StringMap.map ref
        fun usagesOf (k:kept)=getOpt (StringMap.find (!restated,#name (#entry k)),#usages k)
        fun restate (k:kept)=case !(#live k) of NONE => () | SOME {result,bindings,position,light} =>
          let val was=identityOf k
              fun bound (_,value)=UnitBasis.canonical (binderOfValue value)=was
              val later=StringMap.foldl (fn (c:kept,all) =>
                if #index c> #index k andalso List.exists bound (usagesOf c) then c::all else all) [] (#kept old)
          in if null later then () else
            let val keys=List.foldl (fn (c,all) => List.foldl (fn (u as (key,_),all) =>
                  if bound u then StringMap.insert (all,key,()) else all) all (usagesOf c)) StringMap.empty later
                (* what it declared, loaded where it was loaded by need *)
                val (delta,sigs,funs)=if not light then (#delta result,#sigs bindings,#funs bindings) else
                  case needing (fn () => UnitBasis.materialisedOf was) of SOME {delta,sigs,funs} => (delta,sigs,funs)
                  | NONE => (#delta result,#sigs bindings,#funs bindings)
                val saved=(!Env.session,!UnitBasis.sessionFixity,!UnitBasis.sessionSigs,!UnitBasis.sessionFuns,!UnitBasis.binders,
                  !UnitBasis.viewKeys)
                fun back ()=let val (e,f,g,u,b,v)=saved
                  in Env.session:=e;UnitBasis.sessionFixity:=f;UnitBasis.sessionSigs:=g;UnitBasis.sessionFuns:=u;UnitBasis.binders:=b;
                     UnitBasis.viewKeys:=v end
                val ()=(Env.session:=SOME (Env.plus (#env position,delta));
                        (* every key it binds is in what it declared *)
                        UnitBasis.viewKeys:=NONE;
                        UnitBasis.sessionFixity:=Fixity.extend (#fixity position,#directives result);
                        UnitBasis.sessionSigs:=List.foldl (fn ((n,g),m) => StringMap.insert (m,n,g)) (#sigs position) sigs;
                        UnitBasis.sessionFuns:=List.foldl (fn ((n,f),m) => StringMap.insert (m,n,f)) (#funs position) funs;
                        UnitBasis.binders:=List.foldl (fn (key,m) => StringMap.insert (m,key,was)) (#binders position)
                          (if light then #binds k else UnitBasis.bindKeys result))
                val fps=(StringMap.mapi (fn (key,()) => UnitBasis.fingerprintAt (key,was)) keys) handle e => (back ();raise e)
                val ()=back ()
            in List.app (fn c => restated:=StringMap.insert (!restated,#name (#entry c),List.map (fn u as (key,_) =>
                 if bound u then (key,was ^ " " ^ (case StringMap.find (fps,key) of SOME (SOME fp) => fp | _ => "-")) else u)
                 (usagesOf c))) later end end
        (* an elaboration of a unit that is waiting for a walk *)
        val stash=ref NONE : (string*entry*(string*string) list*UnitBasis.exported*Env.origin StringMap.map option*
          ((unit->string list*UnitBasis.unitPath list)->unit)) option ref
        (* the unit elaborated where the session is now: its entry, its usages and
           its export, with the tables as they were found *)
        fun elaborate (source:source,name,allow,keepFacts,start:UnitBasis.start,prior:kept option,key,asked,viewing) =
          let val {file,text,mode}=source
              val keepOpen=isFocused file orelse (asked andalso opening<>Probe)
              (* what a function's name is looked for in, and a position's line *)
              val ()=Source.register (Source.fromStringIn (mode,file,text))
              val ()=Elaborate.forgetLintRecords ()
              val ()=(Error.kept:=[];Error.errors:=0)
              val firstId= !Ast.nextId
              val ()=(observe "unit-start" file (size text);poll ())
              val ((syntaxTree,syntax,outgoing),usages)=Usage.record (fn () =>
                let val ()=List.app (fn name => Usage.use ("fix",name)) (StringMap.listKeys (#table (!fixity)))
                    val syntaxTree=case Option.mapPartial (fn k:kept => case #syntax (#entry k) of
                          SOME tree => if #mode (#entry k)=mode then SOME (#text (#entry k),tree) else NONE | NONE => NONE) prior of
                        SOME (oldText,tree) =>
                          let val change=replacement (oldText,text)
                          in CompilerSyntax.edit (tree,{start= #start change,stop= #stop change,text= #text change,fixity= !fixity}) end
                      | NONE => CompilerSyntax.parse {file=file,text=text,mode=mode,orPatterns=false,fixity= !fixity}
                    val ()=observe "unit-parsed" file (size text)
                    val ()=if keepFacts then attempted:=SOME (name,syntaxTree) else ()
                    (* every syntax error, which ends the unit before it is elaborated *)
                    val ()=case CompilerSyntax.problems syntaxTree of [] => ()
                      | problems => raise UnitFailed (NONE,List.map (fn (span,message) =>
                          CompilerSession.sourceError ("error",span,message)) problems)
                    val syntax=CompilerSyntax.bridge syntaxTree
                    val ()=case query of SOME query => if #unit query=name then
                      (role:=classify (syntax,#offset query);queriedSyntax:=syntax) else () | NONE => ()
                    val outgoing=CompilerSyntax.fixity syntaxTree
                    val ends=IntTable.table 16
                    val ()=List.app (fn stop => IntTable.insert (ends,stop,())) (CompilerSyntax.ends syntaxTree)
                    val ()=Parser.topdecEnds:=StringMap.insert (!Parser.topdecEnds,file,ends)
                    val ()=poll ()
                    val ()=Elaborate.allowPrim:=allow
                    val ()=Elaborate.elabTop (env,syntax)
                    val ()=Elaborate.finish ()
                    val ()=observe "unit-elaborated" file (length(!unitUses))
                    val ()=Env.noteScope ({file=file,start=0,stop=size text+1},!env)
                    val ()=if asked andalso opening=Probe then raise Answered else ()
                    val ()=poll ()
                in (syntaxTree,syntax,outgoing) end)
              (* the declarations that failed, each undone and gone past *)
              val failures=keptErrors ()
              val held=UnitBasis.usagesOf usages
              (* a unit that failed exports what its basis can say: one that an
                 error left a flexible record open in (Elaborate.settleFlex)
                 can say nothing, and is never loaded (tests/units/flex) *)
              val exported=UnitBasis.export {start=start,name=name,file=file,text=fn () => text,
                mode=mode,delta= !Elaborate.lastDelta,fixity=outgoing}
                handle Fail message => if null failures then raise Fail message else
                  {pickle="",sidecar="",identity="",static="",provenance="",own=Vector.tabulate (3,fn _ => IntTable.table 1),
                   counts=Vector.fromList [0,0,0]}
              (* an analysis's identity: its static layer's (D27) *)
              val identity=name ^ "@" ^ #static exported
              (* In a view, what it looked up was in the view, and what its
                 basis names is loaded: else the world loads every basis
                 (UnitBasis.Unviewable), as a compile's warm path compiles
                 again *)
              val ()=if not viewing then () else
                case (case List.find (not o UnitBasis.inView) usages of SOME k => SOME ("its usage " ^ k)
                      | NONE => if #pickle exported="" then NONE else UnitBasis.closedWith (#pickle exported,[],[])) of
                  NONE => ()
                | SOME what => raise UnitBasis.Unviewable (name ^ ": " ^ what)
              (* a type by its unit's name and its path there, which last while
                 the unit's identity moves *)
              val ownPaths=UnitBasis.typePaths (!Elaborate.lastDelta,declared (!Elaborate.insertedSigs,!Elaborate.sigs))
              fun typeId stamp=case IntTable.find (Vector.sub (#own exported,UnitBasis.kTycon),stamp) of
                SOME index => name ^ ":" ^ (case IntTable.find (ownPaths,stamp) of SOME path => path | NONE => "#" ^ Int.toString index)
              | NONE => getOpt (UnitBasis.typeAnchor stamp,
                  name ^ "/local/" ^ key ^ "/" ^ Int.toString (stamp-Vector.sub (#counters start,UnitBasis.kTycon)))
              (* The outgoing environment is fixed while facts are printed.
                 Resolving a tycon's qualified path once per unit avoids
                 walking the entire environment for every occurrence. *)
              val qualified=IntTable.table 64
              val shownTypes=ref [] : (Types.tycon*string option) list ref
              fun qualifiedName (c:Types.tycon)=case IntTable.find(qualified,#stamp c) of
                SOME name=>name | NONE=>let val name=Env.qualifiedName(!env,c)
                  in IntTable.insert(qualified,#stamp c,name);shownTypes:=(c,name):: !shownTypes;name end
              fun frozenType (span:Source.span,ty,derived) =
                let val printer=Types.newPrinter ()
                    fun show ty=Types.toStringNamed (qualifiedName,printer) ty
                    fun domain ty=case Types.prune ty of Types.TRecord fields =>
                      if List.map #1 fields=List.tabulate (length fields,fn i => Int.toString (i+1)) andalso length fields>=2
                      then List.map (show o #2) fields else [show ty] | _ => [show ty]
                    fun arguments ty=case Types.prune ty of Types.TArrow (a,b) => domain a :: arguments b | _ => []
                    val constructors=ref StringMap.empty
                    fun visit ty=case Types.prune ty of Types.TCon (c,args) =>
                        (constructors:=StringMap.insert (!constructors,typeId (#stamp c),());List.app visit args)
                      | Types.TRecord fields => List.app (visit o #2) fields
                      | Types.TArrow (a,b) => (visit a;visit b) | _ => ()
                    val shown=show ty
                    val ()=visit ty
                in {unit=name,file= #file span,start= #start span,stop= #stop span,ty=shown,derived=derived,
                  constructors=StringMap.listKeys (!constructors),arguments=arguments ty}:fact end
              (* a closed unit's too, which its notes keep *)
              val frozenFacts=List.map frozenType (CompilerFacts.collect syntax)
              (* each type name they printed, by what names it beyond this
                 elaboration (printsSo) *)
              val printed=List.mapPartial (fn (c:Types.tycon,shown) =>
                let val s= #stamp c
                    fun mark (unit,number)=SOME {unit=unit,number=number,name= #name c,arity= #arity c,eq= #eq c,shown=shown}:printed option
                in if s<Vector.sub (!UnitBasis.builtin,UnitBasis.kTycon) then mark ("",s)
                   else case IntTable.find (Vector.sub (#own exported,UnitBasis.kTycon),s) of
                     SOME n => mark (identity,n)
                   | NONE => case UnitBasis.rangeOf (UnitBasis.kTycon,s) of
                       SOME (b,u) => mark (#identity u,s-b) | NONE => NONE end) (!shownTypes)
              val typing=if not (keepFacts andalso keepOpen) then NONE else
                SOME (CompilerNodeTypes.capture {tops=List.rev (!Elaborate.tops),ids=(firstId,!Ast.nextId),
                  stamps=(Vector.sub (#counters start,UnitBasis.kStamp),!Elaborate.stampCounter),env= !env})
              val ()=Elaborate.forgetLintRecords ()
              val holding=hold (priorOf,name)
              val typeDefinitions=IntMap.foldRange (fn (stamp,origin,all) => {id=typeId stamp,origin=holding origin} :: all) []
                (Vector.sub (#counters start,UnitBasis.kTycon),!Types.tyconCounter) (!Env.typeOrigins)
              (* what a client of this unit will find, where the unit is here again *)
              val defined=Option.map (fn _ =>
                List.foldl (fn ((key,origin),all) => StringMap.insert (all,key,holding origin)) StringMap.empty
                  (definitions (!Elaborate.lastDelta,declared (!Elaborate.insertedSigs,!Elaborate.sigs),declared (!Elaborate.insertedFuns,!Elaborate.funs)))) prior
              val uses=List.foldl (fn ((role,id,span,origin,derived),all) => (role,id,span,holding origin,derived)::all) [] (!unitUses)
              val ()=UnitBasis.undo start
              val whole={key=key,name=name,file=file,text=text,allow=allow,mode=mode,pickle= #pickle exported,sidecar= #sidecar exported,facts=frozenFacts,
                types=typeDefinitions,syntax=SOME syntaxTree,uses=uses,typing=typing,printed=printed,notes=""}:entry
              (* its notes, where it closes or its sidecar is kept *)
              val keeps=null failures andalso not asked andalso isSome storeDir andalso onDisk (file,text)
              val whole=if keepOpen andalso not keeps then whole else
                {key=key,name=name,file=file,text=text,allow=allow,mode=mode,pickle= #pickle whole,sidecar= #sidecar whole,facts=frozenFacts,
                 types=typeDefinitions,syntax=SOME syntaxTree,uses=uses,typing=typing,printed=printed,notes=notesOf keyOf whole}
              (* its sidecar, once what binds its names and what they reach
                 are known, where it is loaded *)
              fun keep found=if keeps then let val (binds,paths)=found () in keepSidecar (whole,identity,held,#sidecar exported,binds,paths) end
                else ()
          in checked:= !checked+1;(if keepOpen then whole else closedEntry keyOf whole,held,exported,defined,failures,keep) end
          handle Error.CompileError (span,message) =>
                   (UnitBasis.undo start;raise UnitFailed (NONE,keptErrors () @ [CompilerSession.sourceError ("error",span,message)]))
               | error => (UnitBasis.undo start;raise error)
        fun unit (source:source,name,allow,keepFacts,fast) =
          let val {file,text,mode}=source
              val ()=poll ()
              val ()=(Env.currentUnit:=name;unitUses:=[])
              (* a library's unit this session has not held: what another left of it *)
              val prior=case priorOf name of SOME k => SOME k | NONE =>
                case (keepFacts orelse fast,!shares) of
                  (false,SOME shared) =>
                    (case StringMap.find (!shared,name) of SOME (other,k) => if other=config then SOME k else NONE | NONE => NONE)
                | _ => NONE
              val index= !walked
              val ()=walked:=index+1
              val here=place ()
              val asked=case query of SOME query => #unit query=name | NONE => false
              val same=case prior of NONE => false | SOME (k:kept) =>
                #allow (#entry k)=allow andalso #mode (#entry k)=mode andalso #text (#entry k)=text
              val known=case prior of NONE => false | SOME k => UnitBasis.isLoaded (identityOf k)
              val ()=if not fast andalso not (!dirty) andalso not known then cut index else ()
              (* a unit that is open wants what a closed one dropped *)
              val whole=case prior of NONE => false | SOME (k:kept) => not (isFocused file) orelse isOpen (#entry k)
              val ()=if isSome (Source.findFile file) then () else Source.register (Source.fromStringIn (mode,file,text))
              val key=case (prior,same) of (SOME (k:kept),true) => #key (#entry k)
                | _ => keyFor (name,allow,mode,hashOf (file,text))
              val start=UnitBasis.begin (!env,!fixity)
              (* where no session has held it, a compile's entry and its sidecar,
                 for a unit not open: one open is elaborated, for its syntax *)
              val storeKey=case (prior,storeDir,fast orelse asked) of
                  (NONE,SOME _,false) =>
                    let val source=hashOf (file,text)
                    in SOME (UnitCache.keyOf {name=name,source=source,allow=allow,settings=if mode=Source.Ascii then "" else Source.modeName mode},
                             source) end
                | _ => NONE
              val fromStore=case (storeDir,storeKey) of
                  (SOME dir,SOME key) => if isFocused file then NONE else storedUnit (dir,source,name,allow,here,key)
                | _ => NONE
              (* a closed unit asked about, from its notes, where its facts print
                 here as they did and the places its origins hold are as they were *)
              val ()=case (asked andalso opening=Open,prior) of
                  (true,SOME (k:kept)) =>
                    if not known then () else
                      (case (!(#live k),notesOf' (#entry k,identityOf k)) of
                         (SOME {result,...},SOME bytes) =>
                           (case fromNotes (#entry k,bytes,printing (lazyWorld,!env,!UnitBasis.binders,result,#binds k),keyOf) of
                              SOME opened => (openedEntry:=SOME opened;raise Answered)
                            | NONE => ())
                       | _ => ())
                | _ => ()
              (* A unit past a moved identity is taken by its usages. An open one's
                 facts print its types by the paths that reach them where it
                 stands, which no usage covers, so it is elaborated. *)
              val holds=same andalso whole andalso not asked andalso (not (!dirty) orelse
                (not (!moved) orelse not (isFocused file)) andalso
                (case brokenHere (usagesOf (valOf prior)) of NONE => true | SOME _ => (broken:= !broken+1;false)))
              fun compile ()=
                let val (entry,usages,exported,defined,keep)=case !stash of
                      SOME (stashed,entry,usages,exported,defined,keep) =>
                        if stashed<>name then raise Fail "an elaboration kept for another unit" else (stash:=NONE;(entry,usages,exported,defined,keep))
                    | NONE =>
                        (* a unit that failed is not kept, and is elaborated again
                           wherever it is reached: what it read is not all in its
                           usages, since a name it found unbound is not; a
                           question about it has what it holds. Where the world
                           loads by need, in a view of what its text names, or
                           every name for a question of what is visible there *)
                        let val viewing=lazyWorld andalso not (!envWhole)
                            val start=if not viewing then (Env.beyond:=Env.nowhere;UnitBasis.viewKeys:=NONE;start) else
                              (env:=needing (fn () => UnitBasis.lazyView (baseSigs,baseFuns,
                                      if asked andalso opening=Probe then NONE else SOME (viewNames source)));
                               UnitBasis.begin (!env,!fixity))
                            val (entry,usages,exported,defined,failures,keep)=elaborate (source,name,allow,keepFacts,start,prior,key,asked,viewing)
                        in if null failures orelse asked then (entry,usages,exported,defined,keep)
                           else raise UnitFailed (SOME entry,failures) end
                    (* a question has what it asked for, and nothing is loaded *)
                    val ()=if asked then (openedEntry:=SOME entry;raise Answered) else ()
                    val identity=name ^ "@" ^ #static exported
                    fun fresh ()=
                      let val ()=exposed:=true
                          val ()=materialiseNamed (#pickle entry)
                          val result=UnitBasis.loadKnown ({pickle= #pickle entry,sidecar= #sidecar entry,file=file,at= #counters start},SOME identity,[])
                          (* the same unit as a compile's of this text, where its
                             static layer is: what that one's clients name *)
                          val ()=case (storeDir,storeKey) of (SOME dir,SOME (k,_)) => aliasAll (dir,k,identity) | _ => ()
                          val binds=if lazyWorld then UnitBasis.bindKeys result else []
                          val paths=if lazyWorld then getOpt (UnitBasis.pathsOfUnit identity,[]) else []
                      in exposed:=false;
                         keep (fn () => if lazyWorld then (binds,paths) else (UnitBasis.bindKeys result,UnitBasis.unitPaths (#delta result)));
                         (entry,identity,ref (SOME {result=result,bindings= !UnitBasis.lastBindings,position=here,light=false}),
                          usages,ref NONE,ref NONE,binds,paths,false) end
                in case prior of
                     SOME (k:kept) =>
                       if asked then (entry,identityOf k,#live k,usages,#defined k,#keys k,#binds k,#paths k,false)
                       else if identity=identityOf k andalso not (!dirty) andalso known then
                         let val live=liveOf k
                         in cutoff:= !cutoff+1;if fast then () else UnitBasis.rebind (#bindings live);
                            keep (fn () => if lazyWorld then (#binds k,#paths k)
                                           else (UnitBasis.bindKeys (#result live),UnitBasis.unitPaths (#delta (#result live))));
                            (entry,identityOf k,if fast then #live k else ref (SOME {result= #result live,bindings= #bindings live,position=here,light= #light live}),
                             usages,ref defined,#keys k,#binds k,#paths k,false) end
                       else if fast then (stash:=SOME (name,entry,usages,exported,defined,keep);raise NeedWalk)
                       else (if identity=identityOf k then () else (moved:=true;if !dirty orelse not known then () else restate k);
                             if !dirty then () else cut index;fresh ())
                   | NONE => (moved:=true;fresh ()) end
              fun taken (k:kept)=
                let val entry= #entry k
                in if not (!dirty) then
                     (reused:= !reused+1;rebound:= !rebound+1;UnitBasis.rebind (#bindings (liveOf k));
                      SOME (entry,identityOf k,ref (SOME {result= #result (liveOf k),bindings= #bindings (liveOf k),position=here,light= #light (liveOf k)}),
                        usagesOf k,#defined k,#keys k,#binds k,#paths k,false))
                   else
                     let val at=UnitBasis.counters ()
                         (* by need, where it holds by its binders and its basis
                            names the units loaded *)
                         val light=lazyWorld andalso not (null (#binds k)) andalso not (registers (#binds k))
                           andalso UnitBasis.exactEntry (usagesOf k,#pickle entry)
                         val ()=exposed:=true
                         val tried=(SOME (if light then UnitBasis.lightLoad ({pickle= #pickle entry,sidecar= #sidecar entry,file=file,at=at},
                                            identityOf k,#binds k,#paths k)
                             else (materialiseNamed (#pickle entry);
                                   UnitBasis.loadKnown ({pickle= #pickle entry,sidecar= #sidecar entry,file=file,at=at},SOME (identityOf k),
                                     UnitBasis.remappingBasis (#pickle entry,fn identity => StringMap.find (!paths,UnitBasis.canonical identity))))))
                           handle UnitBasis.Missing _ => (UnitBasis.abandon at;NONE) | Pickle.Bad _ => (UnitBasis.abandon at;NONE)
                     in exposed:=false;case tried of
                          SOME result => (reused:= !reused+1;loaded:= !loaded+1;aliasOwn (#pickle entry,identityOf k);
                            if light then byNeed:= !byNeed+1 else ();
                            SOME (entry,identityOf k,ref (SOME {result=result,bindings=if light then noBindings else !UnitBasis.lastBindings,
                                                                position=here,light=light}),
                              usagesOf k,#defined k,ref NONE,
                              if not lazyWorld orelse light then #binds k else UnitBasis.bindKeys result,
                              if not lazyWorld orelse light then #paths k else getOpt (UnitBasis.pathsOfUnit (identityOf k),[]),light))
                        | NONE => NONE end end
              val (entry,identity,live,usages,defined,keys,binds,paths,bound)=
                case fromStore of SOME found => (stored:= !stored+1;reused:= !reused+1;found) | NONE =>
                case (if holds then taken (valOf prior) else NONE) of SOME found => found | NONE => compile ()
              val ()=if asked then
                (openedEntry:=SOME entry;raise Answered) else ()
              (* its names bound: by the keys its basis binds where it was
                 loaded by need (which bound them, bound) *)
              val ()=if fast then () else
                let val {result,light,...}=valOf (!live)
                in exposed:=true;
                   if light then envWhole:=false else ();
                   env:=(if lazyWorld andalso not (!envWhole) then lazyBase else Env.plus (#env start,#delta result));
                   fixity:=Fixity.extend (#fixity start,#directives result);
                   if bound then () else if light then UnitBasis.bindByKeys (identity,binds) else UnitBasis.bind result;
                   exposed:=false end
              val k={entry=entry,identity=identity,live=live,usages=usages,index=index,defined=defined,keys=keys,binds=binds,paths=paths}:kept
          in next:=StringMap.insert (!next,name,k);staged:=name:: !staged;
             observe "unit-frozen" file (length (#uses entry));poll ();k end
        (* each input's names, scanned where its text is new *)
        fun scan (source:source)=
          let val ()=poll ()
              (* what its sidecar says it mentions, where the store has one of
                 this compiler's (a sidecar is a function of the text) *)
              fun stored ()=case storeDir of NONE => NONE | SOME dir =>
                case sideOf (dir,hashOf (#file source,#text source)) of
                  SOME side => if #compiler side=Config.identity andalso #mode side=Source.modeName (#mode source) then
                      Option.map (List.foldl (fn (name,all) => StringMap.insert (all,name,())) StringMap.empty) (#mentions side) else NONE
                | NONE => NONE
              fun fresh ()=
                let val ()=observe "names-start" (#file source) (size (#text source))
                    val found=case stored () of SOME found => found | NONE =>
                      let val (lexemes,_,_)=CompilerSyntax.lexical
                            {file= #file source,text= #text source,mode= #mode source,previous=NONE,change=NONE}
                      in CompilerPrelude.usedBy (#file source,CompilerSyntax.tokens lexemes (#file source),StringMap.empty) end
                in names:=StringMap.insert (!names,#file source,(#mode source,#text source,found));found end
          in case StringMap.find (!names,#file source) of
               SOME (mode,text,found) => if mode= #mode source andalso text= #text source then () else
                 let val keys=fresh () in if StringMap.listKeys keys=StringMap.listKeys found then () else mentions:=true end
             | NONE => (ignore (fresh ());mentions:=true) end
        val ()=if isSome frozenPlan then () else List.app scan sources
        (* what the libraries' indexes rest on, their build files and
           sources (LibraryIndex), once the selection has asked for them *)
        fun manifests ()=case lib of NONE => [] | SOME root =>
          List.concat (List.map (fn dir => LibraryIndex.inputs {root=root,dir=dir})
            (root ^ "/basis"::((LibraryIndex.libraries (root,libraries @ extraLibraries)) handle BasisManifest.Usage _ => [])))
          handle BasisManifest.Usage _ => []
        val stampsHold=List.all (fn (file,stamp) => stampOf file=stamp) (#stamps old)
        fun selected ()=CompilerPrelude.select {lib=lib,libraries=libraries @ extraLibraries,mentioned=
          List.foldl (fn (source:source,all) => case StringMap.find (!names,#file source) of NONE => all
            | SOME (_,_,found) => StringMap.foldli (fn (name,(),all) => StringMap.insert (all,name,())) all found) StringMap.empty sources,
          building=building,view=view}
        val plan=case (frozenPlan,#prelude old) of
            (SOME plan,_) => plan
          | (NONE,SOME plan) => if samePlan andalso sameBuilding andalso stampsHold andalso not (!mentions) then plan else selected ()
          | (NONE,NONE) => selected ()
        val selection=List.map BasisManifest.path (List.concat (#groups plan))
        val priorSelection=List.map (BasisManifest.path o #1) (#libraries old)
        (* and each library in the scope it was in, behind the boundary it had
           (LibraryScope): a place stands only where what it sees does *)
        fun bounds (plan:CompilerPrelude.plan)=List.map (List.map (fn entry:BasisManifest.entry => #scope entry)) (#groups plan)
        val sameScopes=case #prelude old of NONE => false
          | SOME prior => #scopes prior= #scopes plan andalso bounds prior=bounds plan
        val sameSelection=sameScopes andalso selection=priorSelection
        val librarySources=if sameSelection andalso stampsHold then #libraries old else
          List.map (fn entry:BasisManifest.entry =>
            (poll ();(entry,case StringMap.find (!Source.overlays,BasisManifest.path entry) of SOME text => text
              | NONE => #text (Source.readFile (Source.Ascii,BasisManifest.path entry))))) (List.concat (#groups plan))
        val ()=observe "prelude-selected" "" (length librarySources)
        val (libraryNames,inputNames)=if samePlan andalso sameSelection then (#libraryNames old,#units old) else
          let val logical=Workspace.names scope
              val ranks=Workspace.ranks ()
              val libraryNames=List.foldl (fn (entry:BasisManifest.entry,all) =>
                StringMap.insert (all,BasisManifest.path entry,
                  Workspace.fresh (ranks,Workspace.ofEntry (logical,{dir= #dir entry,file= #file entry})))) StringMap.empty (List.concat (#groups plan))
          in (libraryNames,List.map (fn source:source => Workspace.fresh (ranks,Workspace.name (logical,#file source))) sources) end
        val ()=Source.overlays:=List.foldl (fn ((entry,text),overlays) => StringMap.insert
          (overlays,BasisManifest.path entry,text)) (!Source.overlays) librarySources
        val scopes=CompilerBuildContext.new (env,fixity)
        val libraryWalk=LibraryScope.walk (env,fixity,UnitBasis.binders,#scopes plan)
        fun one (entry:BasisManifest.entry)=
          let val k=unit ({file=BasisManifest.path entry,text=valOf (StringMap.find (!Source.overlays,BasisManifest.path entry)),mode=Source.Ascii},
                valOf (StringMap.find (libraryNames,BasisManifest.path entry)),
                (* a seal of a view of the Basis Library is not the Basis's own,
                   as in a compile (src/driver/main.sml, inBasis) *)
                case lib of SOME lib => #dir entry=lib ^ "/basis" andalso not (isSome (#view entry)) | NONE => false,false,false)
          in CompilerBuildContext.note (scopes,#result (liveOf k)) end
        val implemented=ref [] : string list ref
        val remaining=ref (ListPair.zip (sources,inputNames))
        fun snap ()=CompilerBuildContext.snap scopes
        fun delta (before',after)=CompilerBuildContext.delta (scopes,before',after)
        fun apply (before',change,exports)=CompilerBuildContext.apply (scopes,before',change,exports)
        fun walk steps=List.app step steps
        and step item = case item of
          CompilerProject.SUnit (file,annotations) =>
            (case !remaining of [] => raise Fail "missing ordered project input" | (source,name) :: rest =>
              if #file source<>file then raise Fail "project input order differs" else
                (remaining:=rest;
                 CompilerBuildContext.note (scopes,#result (liveOf (unit (source,name,
                   allowPrim orelse List.exists (fn value => value="allowPrim") annotations,true,false))))))
        | CompilerProject.SLibrary (exports,children) =>
            let val before'=snap ()
                val boundary=CompilerBuildContext.enter scopes
                val ()=walk children
                val change=delta (before',snap ())
                val ()=case CompilerBuildContext.exportProblem
                    (if lazyWorld then CompilerBuildContext.bindersChange (change,exports) else change,exports) of
                    NONE => ()
                  | SOME message => raise Error.CompileError ({file=case sources of source :: _ => #file source | [] => "",
                                                               start=0,stop=0},message)
                val ()=CompilerBuildContext.leave (scopes,boundary,exports)
            in apply (before',change,SOME exports) end
        | CompilerProject.SUse (file,children) =>
            if CompilerBuildContext.replay (scopes,file) then () else
              let val before'=snap () val ()=walk children
              in CompilerBuildContext.record (scopes,file,delta (before',snap ()),children) end
        | CompilerProject.SImplements (name,children) =>
            if List.exists (fn prior => prior=name) (!implemented) then raise Fail "duplicate virtual implementation" else
              let val before'=snap ()
                  val boundary=CompilerBuildContext.enter scopes
                  val ()=implemented:=name :: !implemented val ()=walk children
                  val ()=CompilerBuildContext.leave (scopes,boundary,[])
              in apply (before',delta (before',snap ()),SOME []) end
        fun sourceError (span,message)=[CompilerSession.sourceError ("error",span,message)]
        (* the unit that failed, as far as it was elaborated *)
        val failedEntry=ref NONE : entry option ref
        (* Each changed input at its own place, while no identity moves: the
           plan and the libraries as they were, every place standing. A
           unit that fails leaves the units as they are: what follows it is
           unavailable, as it is after a walk, and its place stands. *)
        val placed= #complete old andalso samePlan andalso sameSelection andalso
          ListPair.allEq (fn ((entry,text),(priorEntry,priorText)) =>
            BasisManifest.path entry=BasisManifest.path priorEntry andalso text=priorText) (librarySources,#libraries old)
        val zipped=ListPair.zip (sources,inputNames)
        fun wanted (source:source,name)=case StringMap.find (#kept old,name) of NONE => true
          | SOME (k:kept) => #mode (#entry k)<> #mode source orelse #text (#entry k)<> #text source
              orelse (isFocused (#file source) andalso not (isOpen (#entry k)))
        fun atPlace (source,name,k:kept)=
          (setPlace (#position (liveOf k));walked:= #index k;Env.currentUnit:=name;
           ignore (unit (source,name,#allow (#entry k),true,true)))
        val fast : (CompilerSession.diagnostic list * string option) option =
          if not placed then NONE
          else case query of
            SOME q =>
              (case List.find (fn (_,name) => name= #unit q) zipped of
                 SOME (source,name) => (case StringMap.find (#kept old,name) of
                     SOME k => ((atPlace (source,name,k);SOME ([],NONE))
                       handle Answered => SOME ([],NONE)
                            | UnitFailed (entry,diagnostics) => (failedEntry:=entry;SOME (diagnostics,NONE))
                            | Error.CompileError (span,message) => SOME (sourceError (span,message),NONE))
                   | NONE => NONE)
               | NONE => NONE)
          | NONE =>
            let fun go []=SOME ([],NONE)
                  | go ((source,name)::rest)=if not (wanted (source,name)) then go rest else
                      (case StringMap.find (#kept old,name) of
                         SOME k => ((atPlace (source,name,k);go rest)
                           handle UnitFailed (entry,diagnostics) => (failedEntry:=entry;SOME (diagnostics,SOME name))
                                | Error.CompileError (span,message) => SOME (sourceError (span,message),SOME name))
                       | NONE => NONE)
            in go zipped handle NeedWalk => NONE end
        val finished=ref false
        val unsettled=("","unsettled")
        fun commit ()=
          let val merged=StringMap.unionWith #2 (#kept old,!next)
              val opens=StringMap.foldli (fn (name,k:kept,all) => if isOpen (#entry k) then name::all else all) (#opens old) (!next)
              val (opens,merged)=case !focused of NONE => (opens,merged) | SOME _ =>
                List.foldl (fn (name,(all,map)) => case StringMap.find (map,name) of NONE => (all,map)
                  | SOME (k:kept) => if List.exists (fn other => other=name) all then (all,map)
                      else if not (isOpen (#entry k)) then (all,map)
                      else if isFocused (#file (#entry k)) then (name::all,map)
                      else (all,StringMap.insert (map,name,{entry=closedEntry (fn unit => Option.map (fn k:kept => #key (#entry k))
                             (StringMap.find (merged,unit))) (#entry k),identity= #identity k,live= #live k,
                             usages= #usages k,index= #index k,defined= #defined k,keys= #keys k,binds= #binds k,paths= #paths k}))) ([],merged) opens
          in saved:=(case query of
              SOME _ => {serial= #serial old,kept=merged,order= #order old,opens=opens,complete= #complete old,planned= #planned old,
                prelude= #prelude old,units= #units old,libraryNames= #libraryNames old,libraries= #libraries old,
                stamps= #stamps old,names= #names old,paths= !paths}
            | NONE => {serial= #serial old+1,kept=merged,order=if isSome fast then #order old else List.rev (!staged),opens=opens,
                complete=isSome fast orelse !finished,
                planned=SOME (steps,extraLibraries,building,view),prelude=SOME plan,units=inputNames,libraryNames=libraryNames,
                libraries=librarySources,
                stamps=if sameSelection andalso stampsHold then #stamps old else
                  let val files=manifests () @ selection
                  in (if List.all settled files then [] else [unsettled]) @ List.map (fn file => (file,stampOf file)) files end,
                names= !names,paths= !paths}) end
        val walkErrors=if isSome fast then [] else
          let val ()=(Env.currentUnit:="";env:=Env.initial;fixity:=Fixity.initial;Elaborate.sigs:=baseSigs;Elaborate.funs:=baseFuns;
                Overload.table:=baseOverloads;UnitBasis.binders:=StringMap.empty;UnitBasis.bindLog:=[];walked:=0;envWhole:=true)
              val ()=staged:=[]
              val ()=if samePlan andalso sameSelection then () else (moved:=true;cut 0)
          in (LibraryScope.libraries (libraryWalk,#groups plan,fn (entries,()) => List.app one entries,());
              LibraryScope.program libraryWalk;walk steps;
              if null (!remaining) then () else raise Fail "extra ordered project input";finished:=true;[])
             handle UnitFailed (entry,diagnostics) => (failedEntry:=entry;diagnostics)
                  | Error.CompileError (span,message) => sourceError (span,message)
                  | Answered => []
                  | error => (if !exposed then doomed:=true else ();commit ();raise error) end
        val ()=if isSome fast orelse isSome query then () else walks:= !walks+1
        val failedAt=case fast of SOME (_,at) => at | NONE => NONE
        val errors=case fast of SOME (errors,_) => errors | NONE => walkErrors
        val ()=commit ()
        (* the libraries' units this check reached, for another session to take *)
        val ()=case (!shares,query) of (NONE,_) => () | (_,SOME _) => () | (SOME shared,NONE) =>
          StringMap.app (fn name => case StringMap.find (!next,name) of NONE => () | SOME (k:kept) =>
            shared:=StringMap.insert (!shared,name,(config,{entry= #entry k,identity= #identity k,live=ref NONE,usages= #usages k,
              index= #index k,defined=ref NONE,keys=ref NONE,binds= #binds k,paths= #paths k}))) libraryNames
        val current= !saved
        val ()=poll ()
        val ()=observe "analysis-frozen" "" (!checked)
        val (order,entries)=case (fast,failedAt,errors) of
            (SOME _,NONE,_) => (#order current,#kept current)
          | (SOME _,SOME at,_) =>
              let val limit= #index (valOf (StringMap.find (#kept current,at)))
                  val order=List.filter (fn name => #index (valOf (StringMap.find (#kept current,name)))<limit) (#order current)
              in (order,List.foldl (fn (name,all) => StringMap.insert (all,name,valOf (StringMap.find (#kept current,name)))) StringMap.empty order) end
          | (NONE,_,[]) => (#order current,#kept current)
          | (NONE,_,_::_) => (#order current,List.foldl (fn (name,all) => StringMap.insert (all,name,valOf (StringMap.find (#kept current,name)))) StringMap.empty (#order current))
        (* and the unit that failed, which a question about it is answered from,
           though nothing after it sees it *)
        val entries=case !failedEntry of NONE => entries | SOME (entry:entry) =>
          StringMap.insert (entries,#name entry,{entry=entry,identity="failed",live=ref NONE,usages=[],index= ~1,
            defined=ref NONE,keys=ref NONE,binds=[],paths=[]})
        val ()=if isSome fast then reused:=length order- !checked else ()
        fun candidates ()=case (!scopeEnv,query) of (SOME (_,env,sigs,funs),SOME query) =>
          let val selected=case Env.findStr' (env,#path query) of SOME selected => SOME selected | NONE => NONE
              val holding=hold (priorOf,#unit query)
              fun value (name,status)=
                let val ty=case status of Env.Val {scheme,...} => scheme | Env.Con {scheme,...} => scheme
                      | Env.ConAsVal {scheme,...} => scheme | Env.Prim {scheme,...} => scheme
                      | Env.Exn {ty,...} => ty | Env.ExnAsVal {ty,...} => ty
                    val kind=case status of Env.Con _ => "constructor" | Env.Exn _ => "exception"
                      | _ => (case Types.prune ty of Types.TArrow _ => "function" | _ => "value")
                    val printer=Types.newPrinter ()
                    fun show ty=Types.toStringNamed (fn c => Env.qualifiedName (env,c),printer) ty
                    fun domain ty=case Types.prune ty of Types.TRecord fields =>
                          if List.map #1 fields=List.tabulate (length fields,fn i => Int.toString (i+1)) andalso length fields>=2
                          then List.map (show o #2) fields else [show ty] | _ => [show ty]
                    fun arguments ty=case Types.prune ty of Types.TArrow (a,b) => domain a::arguments b | _ => []
                    val detail=show ty
                in {name=name,kind=kind,detail=SOME detail,arguments=arguments ty,
                  origin=holding (Env.originOf (env,"v",(#path query,name)))}:candidate end
              fun member (kind,name)={name=name,kind=kind,detail=NONE,arguments=[],
                origin=holding (Env.originOf (env,if kind="type" then "t" else "s",(#path query,name)))}:candidate
          in case selected of NONE => [] | SOME selected =>
            List.map value (StringMap.listItemsi (Env.vals selected)) @
            List.map (fn name => member ("type",name)) (StringMap.listKeys (Env.tys selected)) @
            List.map (fn name => member ("structure",name)) (StringMap.listKeys (Env.strs selected)) @
            (if not (null (#path query)) then [] else
              List.map (fn (name,sigma) => {name=name,kind="signature",detail=NONE,arguments=[],origin=holding (#origin sigma)}:candidate) (StringMap.listItemsi sigs) @
              List.map (fn (name,Elaborate.FunInfo {binding,...}) => {name=name,kind="functor",detail=NONE,arguments=[],origin=holding binding}:candidate) (StringMap.listItemsi funs)) end
          | _ => []
        fun fields ()=case query of NONE => [] | SOME query =>
          case CompilerFacts.recordAt (!queriedSyntax,#file query,#offset query) of NONE => [] | SOME ty =>
            case Types.prune ty of Types.TRecord fields =>
              let val printer=Types.newPrinter ()
                  fun show ty=case !scopeEnv of NONE => Types.toStringNamed (fn _ => NONE,printer) ty
                    | SOME (_,env,_,_) => Types.toStringNamed (fn c => Env.qualifiedName (env,c),printer) ty
              in List.map (fn (name,ty) => (name,show ty)) fields end | _ => []
    in {diagnostics=errors,reused= !reused,checked= !checked,
      dependencies=List.map (fn (entry,text) => {file=BasisManifest.path entry,text=text,mode=Source.Ascii}:source) librarySources,
      candidates=candidates (),role= !role,fields=fields (),application=Option.map #2 (!application),
      state=current,entries=entries,order=order,attempted= !attempted,prelude=plan,units=inputNames,opened= !openedEntry,
      route={walked=not (isSome fast),rebound= !rebound,loaded= !loaded,cutoff= !cutoff,broken= !broken,stored= !stored,
        byNeed= !byNeed}} end)
  (* A check. Where a unit elaborated in a view looked up a name outside it,
     or its basis names a unit not loaded, or a view could not be given
     (UnitBasis.Unviewable), the session loads every basis from then on and
     the check is done again so, as a compile's warm path compiles again
     with every basis loaded; an observer is told (lazy-refused) *)
  fun checkWith (args as (session as Session {lazy,state,observer,...},_,_,_,_,_,_,_,_,_,_,_))=
    checkWorld args handle UnitBasis.Unviewable why =>
      (lazy:=false;dropWorld session;state:=unplaced (!state,#serial (!state));
       Option.app (fn f => f {phase="lazy-refused",file=why,checked=0,reused=0,items=0}) (!observer);
       checkWorld args)
  (* whether a session's worlds load their units by need (on at first): a
     change loads every unit again *)
  fun setLazy (session as Session {lazy,state,...},on)=
    if !lazy=on then () else (lazy:=on;dropWorld session;state:=unplaced (!state,#serial (!state)+1))
  (* A closed unit of the session's latest state opened from its notes, where
     it stays loaded and they hold: what a question of its facts or
     occurrences reads, with no check (opened). NONE where they do not, which
     a check at its place answers *)
  fun opened (session as Session {state,world,store,...},name)=
    case !world of NONE => NONE | SOME _ => inWorld (session,fn (_,_,_,lazy) =>
      case StringMap.find (#kept (!state),name) of NONE => NONE | SOME (k:kept) =>
        case !(#live k) of NONE => NONE | SOME {result,position,...} =>
          if not (UnitBasis.isLoaded (identityOf k)) orelse isOpen (#entry k) then NONE else
          let val e= #entry k
              fun keyOf unit=Option.map (fn k:kept => #key (#entry k)) (StringMap.find (#kept (!state),unit))
              val bytes=if #notes e<>"" then SOME (#notes e) else
                case !store of NONE => NONE | SOME dir => storedNotes (dir,UnitCache.sourceHash (#text e),identityOf k)
          in Option.mapPartial (fn bytes => fromNotes (e,bytes,printing (lazy,#env position,#binders position,result,#binds k),keyOf)) bytes end)
  fun checkSteps (session as Session {walks,...},scope,sources,steps,libraries,cancelled,building,view)=
    let val result=checkWith (session,scope,sources,steps,libraries,cancelled,NONE,[],NONE,building,view,Probe)
    in if !walks>=walksToCompact then compact session else ();result end
end
