(* Stable GUI subset implemented by native Windows, SDL3 and mocks.

   Area: Foreign interfaces *)
signature WIN32 =
sig
  (* Shared identities, copied messages and provider exceptions. *)
  structure Types : WIN32_TYPES
  (* Module, native error and monotonic clock support. *)
  structure Kernel :
  sig
    (* `getModuleHandle name` looks up a process module; NONE selects the application module. *)
    val getModuleHandle : string option -> Types.module
    (* `getLastError ()` returns the last captured provider error. *)
    val getLastError : unit -> Word32.word
    (* `setLastError code` sets the provider error value. *)
    val setLastError : Word32.word -> unit
    (* `queryPerformanceCounter ()` reads the monotonic performance counter. *)
    val queryPerformanceCounter : unit -> Int64.int
    (* `queryPerformanceFrequency ()` returns the counter ticks per second. *)
    val queryPerformanceFrequency : unit -> Int64.int
  end
  (* Owning-thread windows, message dispatch, timers and painting. *)
  structure User :
  sig
    (* `registerClassEx specification` registers a named class and a same-thread window procedure. *)
    val registerClassEx : {name : string, instance : Types.module,
                          style : Word32.word,
                          procedure : Types.window * Types.message -> Types.reply} -> Types.atom
    (* `unregisterClass (atom, instance)` unregisters a class after every associated window has ended. *)
    val unregisterClass : Types.atom * Types.module -> unit
    (* `createWindowEx specification` creates a window, delivering NcCreate and Create before returning its identity. *)
    val createWindowEx : {class : Types.atom, instance : Types.module,
                          title : string, style : Word32.word, extendedStyle : Word32.word,
                          x : int, y : int, width : int, height : int,
                          parent : Types.window option} -> Types.window
    (* `destroyWindow window` destroys the window, delivering Destroy and NcDestroy before closing its identity. *)
    val destroyWindow : Types.window -> unit
    (* `showWindow (window, command)` changes visibility and returns the previous visibility. *)
    val showWindow : Types.window * int -> bool
    (* `updateWindow window` processes the pending paint region synchronously. *)
    val updateWindow : Types.window -> unit
    (* `defWindowProc (window, message)` performs the provider default action; Close destroys a live window. *)
    val defWindowProc : Types.window * Types.message -> Int64.int
    (* `getClientRect window` returns its client rectangle. *)
    val getClientRect : Types.window -> Types.rect
    (* `setWindowText (window, text)` sets the title using WTF-8 at native Windows boundaries. *)
    val setWindowText : Types.window * string -> unit
    (* `getMessage filter` waits for a matching queued message or a posted quit status. *)
    val getMessage : {window : Types.window option, minimum : Word32.word,
                      maximum : Word32.word} -> Types.next
    (* `peekMessage filter` returns a matching copied message when available, optionally removing it. *)
    val peekMessage : {window : Types.window option, minimum : Word32.word,
                       maximum : Word32.word, remove : bool} -> Types.queued option
    (* `translateMessage message` requests keyboard text translation and reports whether translation occurred. *)
    val translateMessage : Types.queued -> bool
    (* `dispatchMessage message` dispatches a copied message to its window procedure. *)
    val dispatchMessage : Types.queued -> Int64.int
    (* `discardMessage message` releases an undispatched copied message.

       Both dispatch and discard consume the copy on every returning path. *)
    val discardMessage : Types.queued -> unit
    (* `postQuitMessage status` queues the application quit status. *)
    val postQuitMessage : Int32.int -> unit
    (* `postMessage (window, message)` queues a supported message for later dispatch. *)
    val postMessage : Types.window * Types.message -> unit
    (* `sendMessage (window, message)` dispatches synchronously, permitting nested same-thread sends. *)
    val sendMessage : Types.window * Types.message -> Int64.int
    (* `invalidateRect (window, rectangle, erase)` adds a client rectangle to the pending paint region. *)
    val invalidateRect : Types.window * Types.rect option * bool -> unit
    (* `beginPaint window` begins a paint scope and returns its invalid rectangle. *)
    val beginPaint : Types.window -> Types.paint * Types.rect
    (* `endPaint (window, paint)` ends the matching paint scope and invalidates its drawing capability. *)
    val endPaint : Types.window * Types.paint -> unit
    (* `withPaint window body` runs body inside a paint scope and ends it on every returning path. *)
    val withPaint : Types.window -> (Types.paint * Types.rect -> 'a) -> 'a
    (* `fillRect (paint, rectangle, brush)` fills a rectangle with a live brush. *)
    val fillRect : Types.paint * Types.rect * Types.brush -> unit
    (* `setTimer (window, requested, milliseconds)` creates or replaces an owning-thread message timer and returns its identity. *)
    val setTimer : Types.window * Word64.word * Word32.word -> Word64.word
    (* `killTimer (window, identity)` cancels the associated message timer. *)
    val killTimer : Types.window * Word64.word -> unit
  end
  (* Owned and borrowed drawing objects, geometry and text. *)
  structure Gdi :
  sig
    (* `createPen specification` creates an owned drawing pen. *)
    val createPen : {style : int, width : int, colour : Word32.word} -> Types.pen
    (* `createSolidBrush colour` creates an owned solid colour brush. *)
    val createSolidBrush : Word32.word -> Types.brush
    (* `penObject pen` returns its generic object identity. *)
    val penObject : Types.pen -> Types.object
    (* `brushObject brush` returns its generic object identity. *)
    val brushObject : Types.brush -> Types.object
    (* `objectBrush object` returns a brush view after validating the object kind. *)
    val objectBrush : Types.object -> Types.brush
    (* `selectObject (paint, object)` selects a live drawing object and returns the previous selection of that kind. *)
    val selectObject : Types.paint * Types.object -> Types.object
    (* `deleteObject object` deletes an owned, unselected object; borrowed stock objects are rejected. *)
    val deleteObject : Types.object -> unit
    (* `getStockObject index` returns a borrowed stock drawing object. *)
    val getStockObject : int -> Types.object
    (* `moveToEx (paint, x, y)` sets the current drawing point and returns its previous coordinates. *)
    val moveToEx : Types.paint * int * int -> {x : int, y : int}
    (* `lineTo (paint, x, y)` draws from the current point and updates that point. *)
    val lineTo : Types.paint * int * int -> unit
    (* `rectangle (paint, rectangle)` draws an outline and fills the interior using the selected pen and brush. *)
    val rectangle : Types.paint * Types.rect -> unit
    (* `setTextColor (paint, colour)` sets text colour and returns the previous colour. *)
    val setTextColor : Types.paint * Word32.word -> Word32.word
    (* `setBkMode (paint, mode)` sets transparent or opaque text background mode and returns the previous mode. *)
    val setBkMode : Types.paint * int -> int
    (* `textOut (paint, x, y, text)` draws text through the provider with explicit text and rendering limitations. *)
    val textOut : Types.paint * int * int * string -> unit
  end
end

