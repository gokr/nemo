import std/[unittest, tables, sequtils, strutils]
import src/harding/core/types
import src/harding/core/scheduler
import src/harding/interpreter/vm
import src/harding/interpreter/objects

discard initCoreClasses()

let ctx = newSchedulerContext()
var interp = ctx.mainProcess.getInterpreter()
loadStdlib(interp)

echo "Running first test..."
let result = interp.evalStatements("""
  Coordinator := Processor fork: [
    M := Monitor new.
    Counter := 0.
    Done := 0.
    P1 := Processor fork: [
      10 timesRepeat: [
        M critical: [Counter := Counter + 1].
        Processor yield.
      ].
      Done := Done + 1.
    ].
    P2 := Processor fork: [
      10 timesRepeat: [
        M critical: [Counter := Counter + 1].
        Processor yield.
      ].
      Done := Done + 1.
    ].
    # Wait for both workers to complete
    [Done >= 2] whileFalse: [Processor yield].
    Result := Counter.
  ].
  # Start the coordinator and wait for it
  [Coordinator state = "terminated"] whileFalse: [Scheduler step].
  Result
""")

echo "Error: '", result[1], "'"
echo "Results: ", result[0].len
if result[0].len > 0:
  echo "Last result kind: ", result[0][^1].kind
  if result[0][^1].kind == vkInt:
    echo "Last result intVal: ", result[0][^1].intVal
