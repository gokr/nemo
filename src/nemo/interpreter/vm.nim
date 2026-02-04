## Explicit Stack AST Interpreter for Nemo
##
## This module implements an iterative AST interpreter using an explicit work queue
## instead of recursive Nim procedure calls. This enables:
## 1. True cooperative multitasking (yield within statements)
## 2. Stack reification (thisContext accessible from Nemo)
## 3. No Nim stack overflow on deep recursion
## 4. Easier debugging and profiling

import std/[tables, logging]
import ../core/types
import ../parser/[lexer, parser]
import ./activation
import ./objects
import ./evaluator

type
  VMStatus* = enum
    vmRunning     # Normal execution
    vmYielded     # Processor yielded, can be resumed
    vmCompleted   # Execution finished
    vmError       # Error occurred

  VMResult* = object
    status*: VMStatus
    value*: NodeValue
    error*: string

# Work frame constructors
proc newEvalFrame*(node: Node): WorkFrame =
  WorkFrame(kind: wfEvalNode, node: node)

proc newSendMessageFrame*(selector: string, argCount: int): WorkFrame =
  WorkFrame(kind: wfSendMessage, selector: selector, argCount: argCount)

proc newAfterReceiverFrame*(selector: string, args: seq[Node]): WorkFrame =
  WorkFrame(kind: wfAfterReceiver, pendingSelector: selector, pendingArgs: args, currentArgIndex: 0)

proc newAfterArgFrame*(selector: string, args: seq[Node], currentIndex: int): WorkFrame =
  WorkFrame(kind: wfAfterArg, pendingSelector: selector, pendingArgs: args, currentArgIndex: currentIndex)

proc newApplyBlockFrame*(blockVal: BlockNode, argCount: int): WorkFrame =
  WorkFrame(kind: wfApplyBlock, blockVal: blockVal, argCount: argCount)

proc newReturnValueFrame*(value: NodeValue): WorkFrame =
  WorkFrame(kind: wfReturnValue, returnValue: value)

proc newCascadeFrame*(messages: seq[MessageNode], receiver: NodeValue): WorkFrame =
  WorkFrame(kind: wfCascade, cascadeMessages: messages, cascadeReceiver: receiver)

# Stack operations
proc pushWorkFrame*(interp: var Interpreter, frame: WorkFrame) =
  interp.workQueue.add(frame)

proc popWorkFrame*(interp: var Interpreter): WorkFrame =
  if interp.workQueue.len == 0:
    raise newException(ValueError, "Work queue underflow")
  result = interp.workQueue.pop()

proc hasWorkFrames*(interp: Interpreter): bool =
  interp.workQueue.len > 0

proc pushValue*(interp: var Interpreter, value: NodeValue) =
  interp.evalStack.add(value)

proc popValue*(interp: var Interpreter): NodeValue =
  if interp.evalStack.len == 0:
    raise newException(ValueError, "Eval stack underflow")
  result = interp.evalStack.pop()

proc peekValue*(interp: Interpreter): NodeValue =
  if interp.evalStack.len == 0:
    raise newException(ValueError, "Eval stack empty")
  interp.evalStack[^1]

proc popValues*(interp: var Interpreter, count: int): seq[NodeValue] =
  ## Pop multiple values in reverse order (first argument was pushed first)
  result = newSeq[NodeValue](count)
  for i in countdown(count - 1, 0):
    result[i] = interp.popValue()

# Clear VM state
proc clearVMState*(interp: var Interpreter) =
  interp.workQueue.setLen(0)
  interp.evalStack.setLen(0)

# Handle evaluation of simple nodes (Phase 2)
proc handleEvalNode(interp: var Interpreter, frame: WorkFrame): bool =
  ## Handle wfEvalNode work frame. Returns true if processing should continue.
  let node = frame.node
  if node == nil:
    interp.pushValue(nilValue())
    return true

  case node.kind
  of nkLiteral:
    let lit = cast[LiteralNode](node)
    interp.pushValue(lit.value)
    return true

  of nkIdent:
    let ident = cast[IdentNode](node)
    let value = lookupVariable(interp, ident.name)
    interp.pushValue(value)
    return true

  of nkPseudoVar:
    let pseudo = cast[PseudoVarNode](node)
    case pseudo.name
    of "self":
      if interp.currentReceiver == nil:
        interp.pushValue(nilValue())
      elif interp.currentReceiver.kind == ikObject and
           interp.currentReceiver.slots.len == 0 and
           interp.currentReceiver.isNimProxy == false and
           interp.currentReceiver.nimValue == nil and
           interp.currentReceiver != nilInstance:
        interp.pushValue(interp.currentReceiver.class.toValue())
      else:
        interp.pushValue(interp.currentReceiver.toValue().unwrap())
    of "nil":
      interp.pushValue(nilValue())
    of "true":
      interp.pushValue(trueValue)
    of "false":
      interp.pushValue(falseValue)
    of "super":
      if interp.currentReceiver != nil:
        interp.pushValue(interp.currentReceiver.toValue().unwrap())
      else:
        interp.pushValue(nilValue())
    else:
      interp.pushValue(nilValue())
    return true

  of nkBlock:
    # Block literal - create a copy and capture environment
    let origBlock = cast[BlockNode](node)
    let blockNode = BlockNode(
      parameters: origBlock.parameters,
      temporaries: origBlock.temporaries,
      body: origBlock.body,
      isMethod: origBlock.isMethod,
      capturedEnv: initTable[string, MutableCell](),
      capturedEnvInitialized: true,
      homeActivation: interp.currentActivation
    )
    captureEnvironment(interp, blockNode)
    interp.pushValue(NodeValue(kind: vkBlock, blockVal: blockNode))
    return true

  of nkAssign:
    # Variable assignment: evaluate expression, then assign
    let assign = cast[AssignNode](node)
    # Push continuation frame to handle assignment after expression is evaluated
    interp.pushWorkFrame(WorkFrame(
      kind: wfAfterArg,  # Reuse for assignment continuation
      pendingSelector: "=",  # Special marker for assignment
      pendingArgs: @[],
      currentArgIndex: 0
    ))
    # Extend frame with variable name (store in selector field)
    interp.workQueue[^1].selector = assign.variable
    # Evaluate expression
    interp.pushWorkFrame(newEvalFrame(assign.expression))
    return true

  of nkSlotAccess:
    # Slot access - O(1) direct instance variable access by index
    let slotNode = cast[SlotAccessNode](node)
    if interp.currentReceiver != nil and interp.currentReceiver.kind == ikObject:
      let inst = interp.currentReceiver
      if slotNode.slotIndex >= 0 and slotNode.slotIndex < inst.slots.len:
        if slotNode.isAssignment:
          # Assignment: need to evaluate valueExpr first
          if slotNode.valueExpr != nil:
            # Push continuation to handle slot assignment
            interp.pushWorkFrame(WorkFrame(
              kind: wfAfterArg,
              pendingSelector: ":=",
              currentArgIndex: slotNode.slotIndex
            ))
            interp.pushWorkFrame(newEvalFrame(slotNode.valueExpr))
            return true
          else:
            interp.pushValue(nilValue())
            return true
        else:
          # Read slot value
          interp.pushValue(inst.slots[slotNode.slotIndex])
          return true
    interp.pushValue(nilValue())
    return true

  of nkMessage:
    # Message send - will be implemented in Phase 3
    # For now, push placeholder frames
    let msg = cast[MessageNode](node)

    # First evaluate receiver (or use self if nil)
    if msg.receiver != nil:
      interp.pushWorkFrame(newAfterReceiverFrame(msg.selector, msg.arguments))
      interp.pushWorkFrame(newEvalFrame(msg.receiver))
    else:
      # Implicit self as receiver
      if interp.currentReceiver == nil:
        interp.pushValue(nilValue())
      else:
        interp.pushValue(interp.currentReceiver.toValue().unwrap())
      # Now handle arguments
      if msg.arguments.len == 0:
        interp.pushWorkFrame(newSendMessageFrame(msg.selector, 0))
      else:
        interp.pushWorkFrame(newAfterArgFrame(msg.selector, msg.arguments, 0))
        interp.pushWorkFrame(newEvalFrame(msg.arguments[0]))
    return true

  of nkReturn:
    # Return - will be implemented in Phase 4
    let ret = cast[ReturnNode](node)
    if ret.expression != nil:
      interp.pushWorkFrame(newReturnValueFrame(nilValue()))  # Placeholder
      interp.pushWorkFrame(newEvalFrame(ret.expression))
    else:
      # Return self
      if interp.currentReceiver != nil:
        interp.pushWorkFrame(newReturnValueFrame(interp.currentReceiver.toValue().unwrap()))
      else:
        interp.pushWorkFrame(newReturnValueFrame(nilValue()))
    return true

  of nkArray:
    # Array literal - evaluate elements (Phase 3)
    let arr = cast[ArrayNode](node)
    if arr.elements.len == 0:
      if arrayClass != nil:
        interp.pushValue(newArrayInstance(arrayClass, @[]).toValue())
      else:
        interp.pushValue(NodeValue(kind: vkArray, arrayVal: @[]))
    else:
      # Need to evaluate all elements - push continuation and first element
      # For now, fall through to not implemented
      debug("Array literal not fully implemented in new VM yet")
      interp.pushValue(nilValue())
    return true

  of nkTable:
    # Table literal (Phase 3)
    let tab = cast[TableNode](node)
    if tab.entries.len == 0:
      if tableClass != nil:
        interp.pushValue(newTableInstance(tableClass, initTable[NodeValue, NodeValue]()).toValue())
      else:
        interp.pushValue(NodeValue(kind: vkTable, tableVal: initTable[NodeValue, NodeValue]()))
    else:
      debug("Table literal not fully implemented in new VM yet")
      interp.pushValue(nilValue())
    return true

  of nkCascade:
    # Cascade messages (Phase 5)
    debug("Cascade not implemented in new VM yet")
    interp.pushValue(nilValue())
    return true

  of nkSuperSend:
    # Super send (Phase 5)
    debug("Super send not implemented in new VM yet")
    interp.pushValue(nilValue())
    return true

  of nkObjectLiteral:
    # Object literal
    debug("Object literal not implemented in new VM yet")
    interp.pushValue(nilValue())
    return true

  of nkPrimitive:
    # Primitive - evaluate fallback
    let prim = cast[PrimitiveNode](node)
    if prim.fallback.len > 0:
      # Evaluate fallback statements
      for i in countdown(prim.fallback.len - 1, 0):
        if i < prim.fallback.len - 1:
          # Pop intermediate results (only keep last)
          interp.pushWorkFrame(WorkFrame(kind: wfAfterArg, pendingSelector: "discard"))
        interp.pushWorkFrame(newEvalFrame(prim.fallback[i]))
    else:
      interp.pushValue(nilValue())
    return true

  of nkPrimitiveCall:
    # Primitive call (Phase 3)
    debug("Primitive call not implemented in new VM yet")
    interp.pushValue(nilValue())
    return true

# Handle continuation frames (what to do after subexpression)
proc handleContinuation(interp: var Interpreter, frame: WorkFrame): bool =
  case frame.kind
  of wfAfterReceiver:
    # Receiver is on stack, now evaluate arguments
    if frame.pendingArgs.len == 0:
      # No arguments - send message now
      interp.pushWorkFrame(newSendMessageFrame(frame.pendingSelector, 0))
    else:
      # Evaluate first argument
      interp.pushWorkFrame(newAfterArgFrame(frame.pendingSelector, frame.pendingArgs, 0))
      interp.pushWorkFrame(newEvalFrame(frame.pendingArgs[0]))
    return true

  of wfAfterArg:
    # Special case: assignment continuation
    if frame.pendingSelector == "=":
      let value = interp.popValue()
      setVariable(interp, frame.selector, value)
      interp.pushValue(value)
      return true

    # Special case: slot assignment continuation
    if frame.pendingSelector == ":=":
      let value = interp.popValue()
      if interp.currentReceiver != nil and interp.currentReceiver.kind == ikObject:
        let slotIndex = frame.currentArgIndex
        if slotIndex >= 0 and slotIndex < interp.currentReceiver.slots.len:
          interp.currentReceiver.slots[slotIndex] = value
      interp.pushValue(value)
      return true

    # Special case: discard continuation (for primitive fallback)
    if frame.pendingSelector == "discard":
      discard interp.popValue()
      return true

    # Argument evaluated, check if more
    let nextIndex = frame.currentArgIndex + 1
    if nextIndex < frame.pendingArgs.len:
      # More arguments to evaluate
      interp.pushWorkFrame(newAfterArgFrame(frame.pendingSelector, frame.pendingArgs, nextIndex))
      interp.pushWorkFrame(newEvalFrame(frame.pendingArgs[nextIndex]))
    else:
      # All arguments evaluated - send message
      interp.pushWorkFrame(newSendMessageFrame(frame.pendingSelector, frame.pendingArgs.len))
    return true

  of wfSendMessage:
    # Pop args and receiver, send message
    let args = interp.popValues(frame.argCount)
    let receiverVal = interp.popValue()

    # Handle block invocation
    if receiverVal.kind == vkBlock:
      case frame.selector
      of "value", "value:", "value:value:", "value:value:value:", "value:value:value:value:":
        interp.pushWorkFrame(newApplyBlockFrame(receiverVal.blockVal, args.len))
        # Push args back for block application
        for arg in args:
          interp.pushValue(arg)
        return true
      else:
        discard  # Fall through to regular dispatch

    # Convert receiver to Instance for method lookup
    var receiver: Instance
    case receiverVal.kind
    of vkInstance:
      receiver = receiverVal.instVal
    of vkInt:
      receiver = newIntInstance(integerClass, receiverVal.intVal)
    of vkFloat:
      receiver = newFloatInstance(floatClass, receiverVal.floatVal)
    of vkString:
      receiver = newStringInstance(stringClass, receiverVal.strVal)
    of vkBool:
      receiver = newInstance(booleanClass)
    of vkNil:
      receiver = nilInstance
    of vkArray:
      receiver = newArrayInstance(arrayClass, receiverVal.arrayVal)
    of vkTable:
      receiver = newTableInstance(tableClass, receiverVal.tableVal)
    of vkClass:
      # Class method lookup
      let lookup = evaluator.lookupClassMethod(receiverVal.classVal, frame.selector)
      if lookup.found:
        # Execute class method - will be handled in Phase 3
        debug("Class method dispatch not fully implemented yet")
        interp.pushValue(nilValue())
        return true
      else:
        raise newException(ValueError, "Class method not found: " & frame.selector)
    of vkBlock:
      receiver = newInstance(blockClass)
    of vkSymbol:
      receiver = newStringInstance(stringClass, receiverVal.symVal)

    if receiver == nil:
      raise newException(ValueError, "Cannot send message to nil receiver")

    # Look up method
    let lookup = lookupMethod(interp, receiver, frame.selector)
    if not lookup.found:
      raise newException(ValueError, "Method not found: " & frame.selector & " on " &
        (if receiver.class != nil: receiver.class.name else: "unknown"))

    # Check for native implementation
    let currentMethod = lookup.currentMethod
    if currentMethod.nativeImpl != nil:
      # Call native method
      let savedReceiver = interp.currentReceiver
      try:
        var resultVal: NodeValue
        if currentMethod.hasInterpreterParam:
          type NativeProcWithInterp = proc(interp: var Interpreter, self: Instance, args: seq[NodeValue]): NodeValue {.nimcall.}
          let nativeProc = cast[NativeProcWithInterp](currentMethod.nativeImpl)
          resultVal = nativeProc(interp, receiver, args)
        else:
          type NativeProc = proc(self: Instance, args: seq[NodeValue]): NodeValue {.nimcall.}
          let nativeProc = cast[NativeProc](currentMethod.nativeImpl)
          resultVal = nativeProc(receiver, args)
        interp.pushValue(resultVal)
      finally:
        interp.currentReceiver = savedReceiver
      return true

    # Interpreted method - create activation and execute body
    # (Will be properly implemented in Phase 3)
    debug("Interpreted method execution not fully implemented in new VM yet")

    # Check parameter count
    if currentMethod.parameters.len != args.len:
      raise newException(ValueError,
        "Wrong number of arguments: expected " & $currentMethod.parameters.len &
        ", got " & $args.len)

    # Create activation
    let activation = newActivation(currentMethod, receiver, interp.currentActivation, lookup.definingClass)

    # Bind parameters
    for i in 0..<currentMethod.parameters.len:
      activation.locals[currentMethod.parameters[i]] = args[i]

    # Push activation
    let savedReceiver = interp.currentReceiver
    interp.activationStack.add(activation)
    interp.currentActivation = activation
    interp.currentReceiver = receiver

    # Set home activation for methods
    if currentMethod.isMethod:
      currentMethod.homeActivation = activation

    # Push method body statements in reverse order
    if currentMethod.body.len > 0:
      for i in countdown(currentMethod.body.len - 1, 0):
        if i < currentMethod.body.len - 1:
          # Pop intermediate results
          interp.pushWorkFrame(WorkFrame(kind: wfAfterArg, pendingSelector: "discard"))
        interp.pushWorkFrame(newEvalFrame(currentMethod.body[i]))
    else:
      interp.pushValue(nilValue())

    return true

  of wfApplyBlock:
    # Apply block with args on stack
    let args = interp.popValues(frame.argCount)
    let blockNode = frame.blockVal

    # Check argument count
    if blockNode.parameters.len != args.len:
      raise newException(ValueError,
        "Wrong number of arguments to block: expected " & $blockNode.parameters.len &
        ", got " & $args.len)

    # Block's home activation determines 'self'
    let blockHome = blockNode.homeActivation
    let blockReceiver = if blockHome != nil and blockHome.receiver != nil:
                          blockHome.receiver
                        else:
                          interp.currentReceiver

    # Create activation
    let activation = newActivation(blockNode, blockReceiver, interp.currentActivation)

    # Bind captured environment
    if blockNode.capturedEnvInitialized and blockNode.capturedEnv.len > 0:
      for name, cell in blockNode.capturedEnv:
        activation.locals[name] = cell.value

    # Bind parameters
    for i in 0..<blockNode.parameters.len:
      activation.locals[blockNode.parameters[i]] = args[i]

    # Initialize temporaries
    for tempName in blockNode.temporaries:
      activation.locals[tempName] = nilValue()

    # Push activation
    let savedReceiver = interp.currentReceiver
    interp.activationStack.add(activation)
    interp.currentActivation = activation
    interp.currentReceiver = blockReceiver

    # Push block body statements in reverse order
    if blockNode.body.len > 0:
      for i in countdown(blockNode.body.len - 1, 0):
        if i < blockNode.body.len - 1:
          interp.pushWorkFrame(WorkFrame(kind: wfAfterArg, pendingSelector: "discard"))
        interp.pushWorkFrame(newEvalFrame(blockNode.body[i]))
    else:
      interp.pushValue(nilValue())

    return true

  of wfReturnValue:
    # Handle return - will be properly implemented in Phase 4
    let value = if frame.returnValue.kind != vkNil:
                  frame.returnValue
                else:
                  interp.popValue()

    # Find target activation
    var targetActivation: Activation = nil
    if interp.currentActivation != nil and interp.currentActivation.currentMethod != nil:
      let currentMethod = interp.currentActivation.currentMethod
      if not currentMethod.isMethod and currentMethod.homeActivation != nil:
        targetActivation = currentMethod.homeActivation
      else:
        targetActivation = interp.currentActivation

    if targetActivation != nil:
      targetActivation.returnValue = value.unwrap()
      targetActivation.hasReturned = true

    interp.pushValue(value.unwrap())
    return true

  of wfCascade:
    # Cascade - will be implemented in Phase 5
    debug("Cascade continuation not implemented yet")
    interp.pushValue(nilValue())
    return true

  of wfEvalNode:
    # Should not reach here - wfEvalNode is handled in handleEvalNode
    return handleEvalNode(interp, frame)

# Main execution loop
proc runASTInterpreter*(interp: var Interpreter): VMResult =
  ## Main execution loop for the explicit stack AST interpreter
  ## Returns when:
  ## - Work queue is empty (vmCompleted)
  ## - Processor yields (vmYielded)
  ## - Error occurs (vmError)

  while interp.hasWorkFrames():
    # Check for yield
    if interp.shouldYield:
      interp.shouldYield = false
      return VMResult(status: vmYielded, value: interp.peekValue())

    let frame = interp.popWorkFrame()

    try:
      let shouldContinue = case frame.kind
        of wfEvalNode:
          handleEvalNode(interp, frame)
        else:
          handleContinuation(interp, frame)

      if not shouldContinue:
        break
    except ValueError as e:
      return VMResult(status: vmError, error: e.msg)
    except Exception as e:
      return VMResult(status: vmError, error: "VM error: " & e.msg)

  # Execution complete
  let resultValue = if interp.evalStack.len > 0:
                      interp.evalStack[^1]
                    else:
                      nilValue()

  return VMResult(status: vmCompleted, value: resultValue)

# Entry point to evaluate an expression using the new VM
proc evalWithVM*(interp: var Interpreter, node: Node): NodeValue =
  ## Evaluate an expression using the explicit stack VM
  interp.clearVMState()
  interp.pushWorkFrame(newEvalFrame(node))
  let vmResult = interp.runASTInterpreter()
  case vmResult.status
  of vmCompleted:
    return vmResult.value
  of vmYielded:
    return vmResult.value
  of vmError:
    raise newException(ValueError, vmResult.error)
  of vmRunning:
    return nilValue()

proc doitStackless*(interp: var Interpreter, source: string, dumpAst = false): (NodeValue, string) =
  ## Parse and evaluate source code using the stackless VM
  let tokens = lex(source)
  var parser = initParser(tokens)
  let nodes = parser.parseStatements()

  if parser.hasError:
    return (nilValue(), "Parse error: " & parser.errorMsg)

  if nodes.len == 0:
    return (nilValue(), "No expression to evaluate")

  # Dump AST if requested
  if dumpAst:
    echo "AST:"
    for node in nodes:
      echo printAST(node)

  # Evaluate all nodes using stackless VM, return last result
  try:
    var lastResult = nilValue()
    for node in nodes:
      lastResult = interp.evalWithVM(node)
    interp.lastResult = lastResult
    return (lastResult, "")
  except ValueError as e:
    raise
  except EvalError as e:
    return (nilValue(), "Runtime error: " & e.msg)
  except Exception as e:
    return (nilValue(), "Error: " & e.msg)

proc evalStatementsStackless*(interp: var Interpreter, source: string): (seq[NodeValue], string) =
  ## Parse and evaluate multiple statements using the stackless VM
  let tokens = lex(source)
  var parser = initParser(tokens)
  let nodes = parser.parseStatements()

  if parser.hasError:
    return (@[], "Parse error: " & parser.errorMsg)

  var results = newSeq[NodeValue]()

  try:
    for node in nodes:
      let evalResult = interp.evalWithVM(node)
      results.add(evalResult)
    return (results, "")
  except ValueError as e:
    raise
  except EvalError as e:
    return (@[], "Runtime error: " & e.msg)
  except Exception as e:
    return (@[], "Error: " & e.msg)
