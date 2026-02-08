## ============================================================================
## GtkSourceViewProxy - Source code editor widget wrapper
## ============================================================================

import std/[logging, tables]
import harding/core/types
import harding/interpreter/vm
import ./ffi
import ./widget
import ./textbuffer

type
  GtkSourceViewProxyObj* = object of GtkWidgetProxyObj

  GtkSourceViewProxy* = ref GtkSourceViewProxyObj

## Factory: Create new source view proxy
proc newGtkSourceViewProxy*(widget: GtkSourceView, interp: ptr Interpreter): GtkSourceViewProxy =
  result = GtkSourceViewProxy(
    widget: widget,
    interp: interp,
    signalHandlers: initTable[string, seq[SignalHandler]](),
    destroyed: false
  )
  proxyTable[cast[GtkWidget](widget)] = result

## Initialize GtkSourceView library (call once)
proc initSourceView*() =
  ## Initialize the source view library
  # Note: gtk_source_init() is only needed in some versions
  # The library initializes automatically when first used
  debug("GtkSourceView ready")

## Native class method: new
proc sourceViewNewImpl*(interp: var Interpreter, self: Instance, args: seq[NodeValue]): NodeValue =
  ## Create a new source view with Harding syntax highlighting
  let widget = gtkSourceViewNew()
  let proxy = newGtkSourceViewProxy(widget, addr(interp))

  # Configure the source view
  gtkSourceViewSetShowLineNumbers(widget, 1)
  gtkSourceViewSetHighlightCurrentLine(widget, 1)
  gtkSourceViewSetAutoIndent(widget, 1)
  gtkSourceViewSetIndentOnTab(widget, 1)
  gtkSourceViewSetTabWidth(widget, 2)

  # Set up syntax highlighting for Harding
  let langManager = gtkSourceLanguageManagerGetDefault()
  if langManager != nil:
    # Try to find the Harding language definition
    var hardingLang = gtkSourceLanguageManagerGetLanguage(langManager, "harding")

    # Get or create buffer and set language
    var buffer = gtkTextViewGetBuffer(cast[GtkTextView](widget))
    if buffer == nil:
      if hardingLang != nil:
        buffer = gtkSourceBufferNewWithLanguage(hardingLang)
        gtkSourceBufferSetHighlightSyntax(cast[GtkSourceBuffer](buffer), 1)
        debug("Created source buffer with Harding language")
      else:
        buffer = gtkSourceBufferNew(nil)
        debug("Created source buffer without language (Harding definition not found - install harding.lang to /usr/share/gtksourceview-5/language-specs/ or /usr/share/gtksourceview-4/language-specs/)")
      gtkTextViewSetBuffer(cast[GtkTextView](widget), buffer)
    else:
      # Cast buffer to source buffer and set language
      if hardingLang != nil:
        gtkSourceBufferSetLanguage(cast[GtkSourceBuffer](buffer), hardingLang)
        gtkSourceBufferSetHighlightSyntax(cast[GtkSourceBuffer](buffer), 1)
        debug("Set Harding language on existing buffer")

  var cls: Class = nil
  if "GtkSourceView" in interp.globals[]:
    let val = interp.globals[]["GtkSourceView"]
    if val.kind == vkClass:
      cls = val.classVal
  if cls == nil and "GtkWidget" in interp.globals[]:
    let val = interp.globals[]["GtkWidget"]
    if val.kind == vkClass:
      cls = val.classVal
  if cls == nil:
    cls = objectClass

  let obj = newInstance(cls)
  obj.isNimProxy = true
  storeInstanceWidget(obj, cast[GtkWidget](widget))
  obj.nimValue = cast[pointer](widget)
  return obj.toValue()

## Native instance method: getText:
proc sourceViewGetTextImpl*(interp: var Interpreter, self: Instance, args: seq[NodeValue]): NodeValue =
  ## Get all text from the source view
  if not (self.isNimProxy and self.nimValue != nil):
    return nilValue()

  let widget = cast[GtkSourceView](self.nimValue)

  let buffer = gtkTextViewGetBuffer(cast[GtkTextView](widget))
  if buffer == nil:
    return "".toValue()

  var startIter, endIter: GtkTextIter
  gtkTextBufferGetStartIter(buffer, addr(startIter))
  gtkTextBufferGetEndIter(buffer, addr(endIter))

  let text = gtkTextBufferGetText(buffer, addr(startIter), addr(endIter), 1)
  if text == nil:
    return "".toValue()

  result = toValue($text)

## Native instance method: setText:
proc sourceViewSetTextImpl*(interp: var Interpreter, self: Instance, args: seq[NodeValue]): NodeValue =
  ## Set text in the source view
  if args.len < 1 or args[0].kind != vkString:
    return nilValue()

  if not (self.isNimProxy and self.nimValue != nil):
    return nilValue()

  let widget = cast[GtkSourceView](self.nimValue)

  let buffer = gtkTextViewGetBuffer(cast[GtkTextView](widget))
  if buffer == nil:
    return nilValue()

  gtkTextBufferSetText(buffer, args[0].strVal.cstring, -1)

  debug("Set text in source view")

  nilValue()

## Native instance method: getSelectedText:
proc sourceViewGetSelectedTextImpl*(interp: var Interpreter, self: Instance, args: seq[NodeValue]): NodeValue =
  ## Get selected text or current line if no selection
  if not (self.isNimProxy and self.nimValue != nil):
    return nilValue()

  let widget = cast[GtkSourceView](self.nimValue)
  let buffer = gtkTextViewGetBuffer(cast[GtkTextView](widget))
  if buffer == nil:
    return "".toValue()

  var startIter, endIter: GtkTextIter

  # Check if there's a selection using selection bounds
  let hasSelection = gtkTextBufferGetSelectionBounds(buffer, addr(startIter), addr(endIter))

  if hasSelection == 0:
    # No selection, get current line
    let insertMark = gtkTextBufferGetInsert(buffer)
    gtkTextBufferGetIterAtMark(buffer, addr(startIter), insertMark)
    gtkTextIterSetLineOffset(addr(startIter), 0)
    endIter = startIter
    discard gtkTextIterForwardToLineEnd(addr(endIter))

  let text = gtkTextBufferGetText(buffer, addr(startIter), addr(endIter), 1)
  if text == nil:
    return "".toValue()

  result = toValue($text)

## Native instance method: showLineNumbers:
proc sourceViewShowLineNumbersImpl*(interp: var Interpreter, self: Instance, args: seq[NodeValue]): NodeValue =
  ## Show or hide line numbers
  if args.len < 1 or args[0].kind != vkBool:
    return nilValue()

  if not (self.isNimProxy and self.nimValue != nil):
    return nilValue()

  let widget = cast[GtkSourceView](self.nimValue)
  gtkSourceViewSetShowLineNumbers(widget, if args[0].boolVal: 1 else: 0)
  return nilValue()

## Native instance method: setTabWidth:
proc sourceViewSetTabWidthImpl*(interp: var Interpreter, self: Instance, args: seq[NodeValue]): NodeValue =
  ## Set tab width in spaces
  if args.len < 1 or args[0].kind != vkInt:
    return nilValue()

  if not (self.isNimProxy and self.nimValue != nil):
    return nilValue()

  let widget = cast[GtkSourceView](self.nimValue)
  gtkSourceViewSetTabWidth(widget, args[0].intVal.cuint)
  return nilValue()
