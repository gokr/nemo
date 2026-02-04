## ============================================================================
## Nemo IDE - Main entry point
## Initializes the interpreter, loads GTK bridge, and launches the IDE
## ============================================================================

import std/[os, strutils, logging, tables]
import nemo/core/types
import nemo/core/scheduler
import nemo/interpreter/evaluator
import nemo/interpreter/objects
import nemo/repl/doit
import nemo/repl/cli
import nemo/gui/gtk4/bridge
import nemo/gui/gtk4/ffi
import nemo/gui/gtk4/widget

const
  AppName = "nemo-ide"
  AppDesc = "Nemo IDE - GTK-based graphical IDE"

proc runIde*(opts: CliOptions) =
  ## Main IDE entry point - initializes interpreter and launches IDE

  echo "Starting Nemo IDE..."
  debug("Initializing Nemo IDE")

  # Set NEMO_HOME environment
  putEnv("NEMO_HOME", opts.nemoHome)

  # Create scheduler context (this also initializes the interpreter)
  var ctx = newSchedulerContext()
  var interp = cast[Interpreter](ctx.mainProcess.interpreter)

  # Set nemoHome on the interpreter
  interp.nemoHome = opts.nemoHome

  debug("Scheduler context created")

  # Load standard library
  loadStdlib(interp, opts.bootstrapFile)
  debug("Standard library loaded")

  # Initialize GTK bridge
  initGtkBridge(interp)
  debug("GTK bridge initialized")

  # Load Nemo-side GTK wrapper files
  loadGtkWrapperFiles(interp)
  debug("GTK wrapper files loaded")

  # Load IDE tool files
  loadIdeToolFiles(interp)
  debug("IDE tool files loaded")

  # Run GTK main loop
  debug("Starting GTK main loop")
  when defined(gtk4):
    # GTK4 uses GApplication with proper lifecycle
    let app = gtkApplicationNew("org.nemo.ide", GAPPLICATIONFLAGSNONE)

    # Store the application reference for window creation
    setGtkApplication(app)

    # Connect activate signal - this is where we create/show the window
    proc activateCallback(app: GApplication; data: pointer) {.cdecl.} =
      debug("GTK application activated")
      let interpPtr = cast[ptr Interpreter](data)
      # Launch the IDE by calling Launcher open
      let launchCode = "Launcher open"
      let (_, err) = interpPtr[].evalStatements(launchCode)
      if err.len > 0:
        stderr.writeLine("Error launching IDE: ", err)
        quit(1)

    discard g_signal_connect_data(app, "activate", cast[GCallback](activateCallback), cast[pointer](addr(interp)), nil, 0)

    discard gApplicationRun(cast[GApplication](app), 0, nil)
  else:
    # GTK3 uses gtk_main - simpler approach
    # Launch the IDE by calling Launcher open
    let launchCode = "Launcher open"
    let (_, err) = interp.evalStatements(launchCode)
    if err.len > 0:
      stderr.writeLine("Error launching IDE: ", err)
      quit(1)
    gtkMain()

  debug("GTK main loop exited")

proc main() =
  ## Main entry point

  # Parse command line arguments
  let opts = parseCliOptions(commandLineParams(), AppName, AppDesc)

  # Handle help and version first
  if opts.positionalArgs.len == 1:
    case opts.positionalArgs[0]:
    of "--help", "-h":
      showUsage(AppName, AppDesc)
      quit(0)
    of "--version", "-v":
      echo "Nemo IDE ", VERSION
      quit(0)

  # Configure logging
  setupLogging(opts.logLevel)

  # Run the IDE
  runIde(opts)

# Entry point
when isMainModule:
  main()
