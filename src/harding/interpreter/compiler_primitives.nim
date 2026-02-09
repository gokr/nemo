## Compiler Primitives for Granite
## Exposes compilation functionality as Harding primitives

when defined(granite):
  import std/[os, strutils, strformat, tables]
  import ../core/types
  import ../parser/parser
  import ../parser/lexer
  import ../codegen/module
  import ../compiler/context
  import ../compiler/codegen
  import ../interpreter/vm

  # Global reference to current interpreter (set during primitive calls)
  var currentInterpreter*: Interpreter = nil

  # Forward declarations for primitive implementations
  proc graniteCompileImpl*(self: Instance, args: seq[NodeValue]): NodeValue
  proc graniteCompileToFileImpl*(self: Instance, args: seq[NodeValue]): NodeValue
  proc graniteEvaluateImpl*(self: Instance, args: seq[NodeValue]): NodeValue
  proc graniteGetASTImpl*(self: Instance, args: seq[NodeValue]): NodeValue
  proc graniteBuildImpl*(self: Instance, args: seq[NodeValue]): NodeValue

  type
    CompileResult* = object
      nimCode*: string
      errors*: seq[string]

  proc compileHrdToNim*(source: string, sourcePath: string = ""): CompileResult =
    ## Compile Harding source to Nim code
    result.errors = @[]

    try:
      let tokens = lex(source)
      var parser = initParser(tokens)
      parser.lastLine = 1
      let nodes = parser.parseStatements()

      if parser.hasError:
        result.errors.add(parser.errorMsg)
        return

      let moduleName = if sourcePath.len > 0:
                         changeFileExt(extractFilename(sourcePath), "")
                       else:
                         "generated"

      var ctx = newCompiler("./build", moduleName)
      result.nimCode = genModule(ctx, nodes, moduleName)

    except CatchableError as e:
      result.errors.add("Compilation error: " & e.msg)

  proc evaluateHrd*(interp: Interpreter, source: string): NodeValue =
    ## Compile and execute source directly
    currentInterpreter = interp
    try:
      let result = compileHrdToNim(source, "")

      if result.errors.len > 0:
        return NodeValue(kind: vkString, strVal: result.errors.join("\n"))

      # For now, return the generated code as string
      # Full evaluation would require compiling and running the Nim code
      return NodeValue(kind: vkString, strVal: result.nimCode)

    finally:
      currentInterpreter = nil

  # Primitive: Granite class>>compile: source
  proc graniteCompileImpl*(self: Instance, args: seq[NodeValue]): NodeValue =
    if args.len < 1 or args[0].kind != vkString:
      return NodeValue(kind: vkNil)

    let source = args[0].strVal
    let result = compileHrdToNim(source, "")

    if result.errors.len > 0:
      return NodeValue(kind: vkString, strVal: result.errors.join("\n"))

    return NodeValue(kind: vkString, strVal: result.nimCode)

  # Primitive: Granite class>>compile: source toFile: filename
  proc graniteCompileToFileImpl*(self: Instance, args: seq[NodeValue]): NodeValue =
    if args.len < 2:
      return NodeValue(kind: vkNil)

    let source = args[0].strVal
    let filename = args[1].strVal

    let result = compileHrdToNim(source, "")
    if result.errors.len > 0:
      return NodeValue(kind: vkString, strVal: result.errors.join("\n"))

    try:
      writeFile(filename, result.nimCode)
      return NodeValue(kind: vkBool, boolVal: true)
    except CatchableError:
      return NodeValue(kind: vkBool, boolVal: false)

  # Primitive: Granite class>>evaluate: source
  proc graniteEvaluateImpl*(self: Instance, args: seq[NodeValue]): NodeValue =
    if args.len < 1 or args[0].kind != vkString:
      return NodeValue(kind: vkNil)

    let source = args[0].strVal
    if currentInterpreter != nil:
      return evaluateHrd(currentInterpreter, source)
    else:
      return NodeValue(kind: vkString, strVal: "No interpreter context")

  # Primitive: Granite class>>getAST: source
  proc graniteGetASTImpl*(self: Instance, args: seq[NodeValue]): NodeValue =
    if args.len < 1 or args[0].kind != vkString:
      return NodeValue(kind: vkNil)

    let source = args[0].strVal
    try:
      let tokens = lex(source)
      var parser = initParser(tokens)
      parser.lastLine = 1
      let nodes = parser.parseStatements()

      if parser.hasError:
        return NodeValue(kind: vkString, strVal: "Parse error: " & parser.errorMsg)

      # Return AST as string representation for now
      var astStr = ""
      for node in nodes:
        astStr.add($node.kind)
        astStr.add("\n")

      return NodeValue(kind: vkString, strVal: astStr)

    except CatchableError as e:
      return NodeValue(kind: vkString, strVal: "Error: " & e.msg)

  # Primitive: Granite class>>build: application
  proc graniteBuildImpl*(self: Instance, args: seq[NodeValue]): NodeValue =
    ## Build an Application to binary
    if args.len < 1 or args[0].kind != vkInstance:
      return NodeValue(kind: vkNil)

    let app = args[0].instVal

    # Get application properties
    # These would be accessed via slot indices
    # For now, return a placeholder message

    return NodeValue(kind: vkString, strVal: "Build not yet fully implemented")
