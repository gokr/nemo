#!/usr/bin/env nim
#
# Tests for website code examples
# Verifies that code examples from the website work correctly
#

import std/[unittest, strutils]
import ../src/harding/core/types
import ../src/harding/interpreter/vm

suite "Website Examples - docs.md Example Code":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    loadStdlib(interp)

  test "Hello World (docs.md)":
    let (result, err) = interp.doit("\"Hello, World!\" println")
    check(err.len == 0)
    # println returns string, but we just check no error

  test "Simple block assignment":
    let results = interp.evalStatements("""
      factorial := [:n | n + 1]
      Result := factorial value: 5
    """)
    check(results[1].len == 0)
    check(results[0][^1].kind == vkInt)
    check(results[0][^1].intVal == 6)

  test "IfTrue: block execution":
    let (result, err) = interp.doit("true ifTrue: [42]")
    check(err.len == 0)
    check(result.kind == vkInt)
    check(result.intVal == 42)

suite "Website Examples - features.md Message Passing":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    loadStdlib(interp)

  test "Binary message (3 + 4)":
    let (result, err) = interp.doit("3 + 4")
    check(err.len == 0)
    check(result.intVal == 7)

  test "Unary message class":
    let (result, err) = interp.doit("true class")
    check(err.len == 0)
    check(result.kind == vkClass)

  test "Keyword message Table at:put:":
    let results = interp.evalStatements("""
      T := Table new
      T at: "foo" put: 42
      Result := T at: "foo"
    """)
    check(results[1].len == 0)
    check(results[0][^1].kind == vkInt)
    check(results[0][^1].intVal == 42)

suite "Website Examples - features.md Modern Syntax":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    loadStdlib(interp)

  test "Optional periods (no period)":
    let results = interp.evalStatements("""
      x := 1
      y := 2
      Result := x + y
    """)
    check(results[1].len == 0)
    check(results[0][^1].intVal == 3)

  test "Double-quoted strings":
    let (result, err) = interp.doit("\"Double quotes\"")
    check(err.len == 0)
    check(result.kind == vkString)
    check(result.strVal == "Double quotes")

suite "Website Examples - features.md Class Creation":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    loadStdlib(interp)

  test "Class creation with derive":
    let results = interp.evalStatements("Point := Object derive: #(x y)")
    check(results[1].len == 0)
    check(results[0][0].kind == vkClass)

  test "Method definition with selector:put:":
    let results = interp.evalStatements("""
      Calculator := Object derive
      Calculator selector: #add:to: put: [:x :y | x + y]
      C := Calculator new
      Result := C add: 5 to: 10
    """)
    check(results[1].len == 0)
    check(results[0][^1].kind == vkInt)
    check(results[0][^1].intVal == 15)

  test "Instance creation with new":
    let results = interp.evalStatements("""
      Point := Object derive: #(x y)
      p := Point new
      Result := p class
    """)
    check(results[1].len == 0)
    check(results[0][^1].kind == vkClass)

suite "Website Examples - features.md Collections":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    loadStdlib(interp)

  test "Array literal":
    let (result, err) = interp.doit("#(1 2 3 4 5)")
    check(err.len == 0)
    check(result.instVal.kind == ikArray)
    check(result.instVal.elements.len == 5)

  test "Table literal":
    let (result, err) = interp.doit("#{\"Alice\" -> 95}")
    check(err.len == 0)
    check(result.kind == vkInstance)
    check(result.instVal.kind == ikTable)

  test "Array element access (at:)":
    let results = interp.evalStatements("""
      arr := #(10 20 30)
      Result := arr at: 2
    """)
    check(results[1].len == 0)
    check(results[0][^1].kind == vkInt)
    check(results[0][^1].intVal == 20)

suite "Website Examples - Control Flow":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    loadStdlib(interp)

  test "true ifTrue: executes block":
    let (result, err) = interp.doit("true ifTrue: [42]")
    check(err.len == 0)
    check(result.intVal == 42)

  test "false ifFalse: executes block":
    let (result, err) = interp.doit("false ifFalse: [99]")
    check(err.len == 0)
    check(result.intVal == 99)

  test "Block value: invocation":
    let (result, err) = interp.doit("[:x | x * 2] value: 5")
    check(err.len == 0)
    check(result.intVal == 10)

suite "Website Examples - Boolean Operations":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    loadStdlib(interp)

  test "Boolean equality":
    let (result, err) = interp.doit("true = true")
    check(err.len == 0)

  test "Boolean not equal":
    let (result, err) = interp.doit("true ~= false")
    check(err.len == 0)

suite "Website Examples - Arithmetic":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    loadStdlib(interp)

  test "Addition":
    let (result, err) = interp.doit("3 + 4")
    check(err.len == 0)
    check(result.intVal == 7)

  test "Subtraction":
    let (result, err) = interp.doit("10 - 3")
    check(err.len == 0)
    check(result.intVal == 7)

  test "Multiplication":
    let (result, err) = interp.doit("6 * 7")
    check(err.len == 0)
    check(result.intVal == 42)

  test "Division":
    let (result, err) = interp.doit("10 / 2")
    check(err.len == 0)
    check(result.kind == vkFloat)

  test "Integer division (//)":
    let (result, err) = interp.doit("10 // 3")
    check(err.len == 0)
    check(result.intVal == 3)

  test "Modulo (%)":
    let (result, err) = interp.doit("10 % 3")
    check(err.len == 0)
    check(result.intVal == 1)

suite "Website Examples - Comparison":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    loadStdlib(interp)

  test "Less than":
    let (result, err) = interp.doit("3 < 5")
    check(err.len == 0)

  test "Greater than":
    let (result, err) = interp.doit("5 > 3")
    check(err.len == 0)

  test "Less than or equal":
    let (result, err) = interp.doit("3 <= 3")
    check(err.len == 0)

  test "Greater than or equal":
    let (result, err) = interp.doit("5 >= 3")
    check(err.len == 0)

  test "Equality with =":
    let (result, err) = interp.doit("3 = 3")
    check(err.len == 0)

suite "Website Examples - String Operations":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    loadStdlib(interp)

  test "String literal":
    let (result, err) = interp.doit("\"Hello\"")
    check(err.len == 0)
    check(result.kind == vkString)
    check(result.strVal == "Hello")

  test "String size":
    let (result, err) = interp.doit("\"Hello\" size")
    check(err.len == 0)
    check(result.intVal == 5)

  test "String at: index":
    let (result, err) = interp.doit("\"ABC\" at: 2")
    check(err.len == 0)
    check(result.strVal == "B")

suite "Website Examples - REPL Examples":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    loadStdlib(interp)

  test "REPL sequence 1 - Basic arithmetic":
    let results = interp.evalStatements("3 + 4")
    check(results[1].len == 0)
    check(results[0][0].intVal == 7)

  test "REPL sequence 2 - Collections":
    let results = interp.evalStatements("""
      numbers := #(1 2 3 4 5)
      Result := numbers size
    """)
    check(results[1].len == 0)
    check(results[0][^1].intVal == 5)

  test "REPL sequence 3 - Table":
    let results = interp.evalStatements("""
      T := Table new
      T at: "key" put: "value"
      Result := T at: "key"
    """)
    check(results[1].len == 0)
    check(results[0][^1].strVal == "value")

suite "Website Examples - index.md Quick Start":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    loadStdlib(interp)

  test "Quick Start: 3 + 4":
    let (result, err) = interp.doit("3 + 4")
    check(err.len == 0)
    check(result.intVal == 7)

  test "Quick Start: Array literal":
    let (result, err) = interp.doit("#(1 2 3)")
    check(err.len == 0)
    check(result.instVal.kind == ikArray)
    check(result.instVal.elements.len == 3)

suite "Website Examples - differences from Smalltalk":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    loadStdlib(interp)

  test "Hash comments":
    let source = """
      # This is a comment
      3 + 4
    """.strip()
    let (result, err) = interp.doit(source)
    check(err.len == 0)
    check(result.intVal == 7)

  test "Double-quoted strings":
    let (result, err) = interp.doit("\"Hello\"")
    check(err.len == 0)
    check(result.kind == vkString)

  test "Optional periods (newline separator)":
    let results = interp.evalStatements("""
      x := 1
      y := 2
      Result := x + y
    """)
    check(results[1].len == 0)
    check(results[0][^1].intVal == 3)
    check(results[0][0].intVal == 1)
    check(results[0][1].intVal == 2)

suite "Website Examples - docs.md Factorial":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    loadStdlib(interp)

  test "Factorial (docs.md)":
    let results = interp.evalStatements("""
      | factorial |
      factorial := [:n |
          (n <= 1) ifTrue: [^ 1].
          ^ n * (factorial value: (n - 1))
      ]
      Result := factorial value: 5
    """)
    check(results[1].len == 0)
    check(results[0][^1].kind == vkInt)
    check(results[0][^1].intVal == 120)

suite "Website Examples - docs.md Counter Class":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    loadStdlib(interp)

  test "Counter class (docs.md)":
    let results = interp.evalStatements("""
      | c |
      Counter := Object derive: #(count)
      Counter >> initialize [ count := 0 ]
      Counter >> value [ ^count ]
      Counter >> increment [ ^count := count + 1]

      c := Counter new
      c initialize
      c increment
      Result := c value
    """)
    check(results[1].len == 0)
    check(results[0][^1].kind == vkInt)
    check(results[0][^1].intVal == 1)

suite "Website Examples - docs.md Table":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    loadStdlib(interp)

  test "Table literal with entries (docs.md)":
    let results = interp.evalStatements("""
      scores := #{"Alice" -> 95, "Bob" -> 87}
      Result := scores at: "Alice"
    """)
    check(results[1].len == 0)
    check(results[0][^1].intVal == 95)

suite "Website Examples - index.md deriveWithAccessors":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    loadStdlib(interp)

  test "deriveWithAccessors creates getters and setters":
    let results = interp.evalStatements("""
      Point := Object deriveWithAccessors: #(x y)
      p := Point new
      p x: 100
      p y: 200
      Result := p x
    """)
    check(results[1].len == 0)
    check(results[0][^1].intVal == 100)

  test "Point + operator with aPoint x syntax":
    let results = interp.evalStatements("""
      Point := Object deriveWithAccessors: #(x y)
      Point >>+ aPoint [
          x := x + aPoint x
          y := y + aPoint y
      ]
      p1 := Point new x: 10; y: 20
      p2 := Point new x: 5; y: 10
      p1 + p2
      Result := p1 x
    """)
    check(results[1].len == 0)
    check(results[0][^1].intVal == 15)

suite "Website Examples - features.md Point Class":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    loadStdlib(interp)

  test "Point class with extend: for multiple methods":
    let results = interp.evalStatements("""
      | p |
      Point := Object derive: #(x y)
      Point >> x: val [ x := val ]
      Point >> y: val [ y := val ]

      Point extend: [
          self >> moveBy: dx and: dy [
              x := x + dx.
              y := y + dy
          ]
          self >> distanceFromOrigin [
              ^ ((x * x) + (y * y)) sqrt
          ]
      ]

      p := Point new
      p x: 100; y: 200
      Result := p distanceFromOrigin
    """)
    check(results[1].len == 0)
    check(results[0][^1].kind == vkFloat)

suite "Website Examples - features.md Collection Methods":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    loadStdlib(interp)

  test "collect: transformation":
    let results = interp.evalStatements("""
      numbers := #(1 2 3 4 5)
      squares := numbers collect: [:n | n * n]
      Result := squares at: 3
    """)
    check(results[1].len == 0)
    check(results[0][^1].intVal == 9)

  test "select: filter with modulus":
    let results = interp.evalStatements("""
      numbers := #(1 2 3 4 5)
      evens := numbers select: [:n | (n % 2) = 0]
      Result := evens size
    """)
    check(results[1].len == 0)
    check(results[0][^1].intVal == 2)

  test "inject:into: reduce":
    let results = interp.evalStatements("""
      numbers := #(1 2 3 4 5)
      sum := numbers inject: 0 into: [:acc :n | acc + n]
      Result := sum
    """)
    check(results[1].len == 0)
    check(results[0][^1].intVal == 15)

  test "do: iteration":
    let results = interp.evalStatements("""
      | sum |
      sum := 0.
      #(1 2 3) do: [:n | sum := sum + n].
      Result := sum
    """)
    check(results[1].len == 0)
    check(results[0][^1].intVal == 6)

  test "detect: find first matching":
    let results = interp.evalStatements("""
      numbers := #(1 2 3 4 5)
      three := numbers detect: [:n | n = 3]
      Result := three
    """)
    check(results[1].len == 0)
    check(results[0][^1].intVal == 3)

suite "Website Examples - features.md Class-Side Methods":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    loadStdlib(interp)

  test "class>> defines class-side method":
    let results = interp.evalStatements("""
      Person := Object derive: #(name age)
      Person >> initialize [ name := ""; age := 0 ]
      Person >> name: n aged: a [ name := n; age := a ]
      Person class >> newNamed: n aged: a [
        | p |
        p := self new.
        p name: n.
        p age: a.
        ^ p
      ]
      alice := Person newNamed: "Alice" aged: 30
      Result := alice age
    """)
    check(results[1].len == 0)
    check(results[0][^1].intVal == 30)

suite "Website Examples - features.md Dynamic Dispatch":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    loadStdlib(interp)

  test "perform: without arguments":
    let results = interp.evalStatements("""
      numbers := #(1 2 3)
      Result := numbers perform: #size
    """)
    check(results[1].len == 0)
    check(results[0][^1].intVal == 3)

  test "perform:with: with one argument":
    let results = interp.evalStatements("""
      numbers := #(10 20 30)
      Result := numbers perform: #at: with: 2
    """)
    check(results[1].len == 0)
    check(results[0][^1].intVal == 20)

suite "Website Examples - Nil Object":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    loadStdlib(interp)

  test "nil isNil returns true":
    let (result, err) = interp.doit("nil isNil")
    check(err.len == 0)

  test "nil class returns UndefinedObject":
    let (result, err) = interp.doit("nil class name")
    check(err.len == 0)
    check(result.kind == vkString)
    check(result.strVal == "UndefinedObject")

suite "Website Examples - Math Operations":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    loadStdlib(interp)

  test "sqrt of number":
    let results = interp.evalStatements("""
      Result := 16 sqrt
    """)
    check(results[1].len == 0)
    check(results[0][^1].kind == vkFloat)
    check(results[0][^1].floatVal > 3.9)

  test "distanceFromOrigin calculation":
    let results = interp.evalStatements("""
      | x y |
      x := 3.
      y := 4.
      Result := ((x * x) + (y * y)) sqrt
    """)
    check(results[1].len == 0)
    check(results[0][^1].floatVal > 4.9)

suite "Website Examples - Block Return":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    loadStdlib(interp)

  test "Non-local return from block":
    let results = interp.evalStatements("""
      | findPositive |
      findPositive := [:arr |
          arr do: [:n |
              (n > 0) ifTrue: [^ n]
          ].
          ^ nil
      ]
      Result := findPositive value: #(-1 -2 5 -3)
    """)
    check(results[1].len == 0)
    check(results[0][^1].kind == vkInt)
    check(results[0][^1].intVal == 5)
