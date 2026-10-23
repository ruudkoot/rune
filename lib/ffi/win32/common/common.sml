(* Implements: WIN32_COMMON *)
structure Win32Common :> WIN32_COMMON =
struct
  structure Types =
  struct
    datatype window=Window of IntInf.int
    datatype module=Module of IntInf.int
    datatype atom=Atom of IntInf.int
    datatype paint=PaintScope of IntInf.int
    datatype object=Object of IntInf.int
    datatype pen=Pen of object
    datatype brush=Brush of object
    type rect={left:Int32.int,top:Int32.int,right:Int32.int,bottom:Int32.int}
    datatype message=NcCreate | Create | Size of {width:int,height:int} | Paint | Close | Destroy | NcDestroy
      | KeyDown of {key:Word32.word,repeated:bool} | KeyUp of Word32.word | Char of Word16.word
      | MouseMove of {x:int,y:int,buttons:Word32.word} | ButtonDown of {button:int,x:int,y:int}
      | ButtonUp of {button:int,x:int,y:int} | Timer of Word64.word
      | Application of {code:Word32.word,w:Word64.word,l:Int64.int} | Unknown of Word32.word
    datatype reply=Default | Result of Int64.int
    datatype queued=Queued of IntInf.int
    datatype next=Quit of Int32.int | Message of queued
    exception Error of {function:string,code:Word32.word}
    exception Unsupported of string
  end
  val next=ref(0:IntInf.int)
  fun fresh constructor=let val n=IntInf.+(!next,1) in next:=n;constructor n end
  fun freshWindow()=fresh Types.Window
  fun freshModule()=fresh Types.Module
  fun freshAtom()=fresh Types.Atom
  fun freshPaint()=fresh Types.PaintScope
  fun freshObject()=fresh Types.Object
  fun freshPen()=Types.Pen(freshObject())
  fun freshBrush()=Types.Brush(freshObject())
  fun freshQueued()=fresh Types.Queued
  fun penObject(Types.Pen object)=object
  fun brushObject(Types.Brush object)=object
  fun objectBrush object=Types.Brush object
  fun windowKey(Types.Window n)=n
  fun moduleKey(Types.Module n)=n
  fun atomKey(Types.Atom n)=n
  fun paintKey(Types.PaintScope n)=n
  fun objectKey(Types.Object n)=n
  fun queuedKey(Types.Queued n)=n
end
