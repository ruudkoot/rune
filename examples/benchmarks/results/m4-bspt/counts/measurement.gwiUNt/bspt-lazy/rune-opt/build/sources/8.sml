(* Original MGR control-string protocol and screen parameters.
   Individual command strings are portable text; no window-system FFI is used. *)
structure BenchBSPTUI =
struct
  datatype command=Polygon|Union|Intersect|Subtract|Complement|Partition
    |Render|Classify|Area|Quit|Null
  type button=command*int*string
  val delimiter="         "
  val buttonIndent=5 val buttonWidth=110 val buttonHeight=40
  val textIn=9 val textDown=30
  val renderLeft=120 val renderTop=0 val renderHeight=510
  val windowWidth=900 val windowHeight=700
  val renderRegion=[120,0,900,510]
  val windowRegion=[0,0,900,700]
  val textRegion=[0,515,115,50]
  val treeRegion=[120,515,780,190]
  val noTextRegion=treeRegion val mouseRegion=windowRegion
  val buttons:button list=[
    (Polygon,10,"   Polygon    "),(Union,60,"    Union     "),
    (Intersect,110,"  Intersect   "),(Subtract,160,"   Subtract   "),
    (Complement,210,"  Complement  "),(Partition,260,"Partitionings "),
    (Render,310,"    Render    "),(Classify,360,"Classify Point"),
    (Area,410,"     Area     "),(Quit,460,"     Quit     ")]
  fun integer n=String.translate(fn #"~"=>"-"|c=>String.str c)(Int.toString n)
  fun largeInteger n=String.translate(fn #"~"=>"-"|c=>String.str c)(IntInf.toString n)
  val escape=String.str(Char.chr 27)
  fun command suffix values=escape^(if List.null values then""else String.concatWith","(List.map integer values)^suffix)
  fun largeCommand suffix values=escape^(if List.null values then""else String.concatWith","(List.map largeInteger values)^suffix)
  fun setTextRegion values=command"t"values
  val textReset=escape^"t"
  val clear=String.str(Char.chr 12)
  fun mapEvent event=if event=3 orelse event=4 then 2-event else event
  fun setEvent event text=command("e"^text)[mapEvent event,String.size text]
  fun clearEvent event=command"e"[mapEvent event]
  fun func mode=command"b"[mode]
  fun line values=command"l"values
  fun largeLine values=largeCommand"l"values
  fun setCursor n=command"h"[n]
  fun setMode n=command"S"[n]
  fun shapeWindow values=command"W"values
  fun stringTo window x y text=command("."^text)[window,x,y,String.size text]
  fun blanks n=String.implode(List.tabulate(n,fn _=> #" "))
  fun printOver x y text=String.concat[
    func 0,stringTo 0 x y(blanks(String.size text)),func 4,stringTo 0 x y text,func 15]
  fun movePrintTo x y text=String.concat[func 4,stringTo 0 x y text,func 15]
  fun writeVert(x,y)[]=""
    |writeVert(x,y)(text::rest)=printOver x y text^writeVert(x,y+11)rest
  fun toScreenRegion()=setTextRegion windowRegion
  fun toNoTextRegion()=setTextRegion noTextRegion
  fun toTextRegion()=setTextRegion textRegion
  fun toMouseRegion()=setTextRegion mouseRegion
  fun inside[top,left,width,height]=[top+1,left+1,width-2,height-2]
    |inside _=raise Match
  fun clearRegion values=String.concat[setTextRegion(inside values),clear,toNoTextRegion()]
  fun clearRender()=clearRegion renderRegion
  fun clearTree()=clearRegion treeRegion
  fun clearText()=clear
  fun button depth=[buttonIndent,depth,buttonWidth,buttonHeight]
  fun clearButton(_,depth,_)=clearRegion(button depth)
  fun drawBox[x,y,width,height]=String.concat[
       line[x,y,x,y+height],line[x,y+height,x+width,y+height],
       line[x+width,y+height,x+width,y],line[x+width,y,x,y]]
    |drawBox _=raise Match
  fun drawButton(_,depth,name)=printOver textIn(depth+textDown)name^
    drawBox[buttonIndent,depth,buttonWidth,buttonHeight]
  fun mapcatButton f cmd []=""
    |mapcatButton f cmd((item as(cmd',_,_))::rest)=
      if cmd=cmd' then String.concat(List.map f rest)else f item^mapcatButton f cmd rest
  fun mark cmd=toScreenRegion()^mapcatButton clearButton cmd buttons^toNoTextRegion()
  fun noMark cmd=toScreenRegion()^
    mapcatButton(fn(_,depth,name)=>movePrintTo textIn(depth+textDown)name)cmd buttons^toNoTextRegion()
  fun spacer(a,b)=String.implode[a,#" ",b]
  fun zipped a b=ListPair.map spacer(String.explode a,String.explode b)
  fun labelButtons(a,b)(c,d)=String.concat[
    toMouseRegion(),writeVert(48,585)(zipped a b),writeVert(83,585)(zipped c d),toNoTextRegion()]
  fun unlabelButtons()=labelButtons("BUTTON   ","DISABLED ")("SELECT   ","OPERATION")
  fun labelDefinePoly()=labelButtons("COMPLETE ","POLYGON  ")("DEFINE   ","VERTEX   ")
  fun labelClassify()=labelButtons("FINISH   ","CLASSIFY ")("CLASSIFY ","POINT    ")
  fun drawMouse()=String.concat[
    movePrintTo 43 688"Mouse",drawBox[5,565,110,122],
    drawBox[10,570,30,104],drawBox[45,570,30,104],drawBox[80,570,30,104],
    writeVert(13,585)(zipped"RESERVED""SYSTEM !"),unlabelButtons()]
  fun drawScreen()=String.concat[
    line[0,511,900,511],line[119,0,119,700],String.concat(List.map drawButton buttons),drawMouse()]
  val initialiseMouse=setEvent 1"%p\n"^setEvent 2(delimiter^"\n")
  val initialiseScreen=setMode 7^setCursor 5^textReset^clear^drawScreen()^toNoTextRegion()
  fun reset()=mark Quit^textReset^setCursor 0
  fun indicate Null _=""
    |indicate cmd actions=mark cmd^String.concat actions^noMark cmd
end
