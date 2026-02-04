## ============================================================================
## GtkMenuBarProxy - MenuBar widget wrapper
## ============================================================================

import std/[logging, tables]
import nemo/core/types
import nemo/interpreter/evaluator
import ./ffi
import ./widget

type
  GtkMenuBarProxyObj* {.acyclic.} = object of QWidgetProxyObj

  GtkMenuBarProxy* = ref GtkMenuBarProxyObj

## Factory: Create new menu bar proxy
proc newGtkMenuBarProxy*(widget: GtkMenuBar, interp: ptr Interpreter): GtkMenuBarProxy =
  result = GtkMenuBarProxy()

## Native method: append:
proc menuBarAppendImpl*(interp: var Interpreter, self: Instance, args: seq[NodeValue]): NodeValue =
  ## Append a menu item to the menu bar
  if args.len < 1:
    return nilValue()

  if not (self.isNimProxy and self.nimValue != nil):
    return nilValue()

  let menuItemVal = args[0]
  if menuItemVal.kind != vkInstance or not menuItemVal.instVal.isNimProxy:
    return nilValue()

  let menuBarProxy = cast[GtkMenuBarProxy](self.nimValue)
  if menuBarProxy.widget == nil:
    return nilValue()

  let menuItemProxy = cast[QWidgetProxy](menuItemVal.instVal.nimValue)
  if menuItemProxy.widget == nil:
    return nilValue()

  when defined(gtk4):
    # GTK4: use gtkBoxAppend since GtkMenuBar is a GtkBox
    gtkBoxAppend(cast[GtkBox](menuBarProxy.widget), menuItemProxy.widget)
  else:
    # GTK3: use gtkShellAppend
    gtkShellAppend(menuBarProxy.widget, menuItemProxy.widget)

  debug("Appended menu item to menu bar")

  nilValue()
