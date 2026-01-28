#!/usr/bin/env nim
#
# Tests for super keyword and >> method definition syntax
#

import std/[unittest, logging, strutils]
import ../src/nimtalk/core/types
import ../src/nimtalk/parser/[lexer, parser]
import ../src/nimtalk/interpreter/[evaluator, objects]

configureLogging(lvlError)

suite "Super Keyword Support":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    initSymbolTable()

  test "super calls parent method":
    let result = interp.evalStatements("""
    Parent := Dictionary derive.
    Parent at: "greet" put: [ "Hello from parent" ].
    Child := Parent derive.
    Child at: "greet" put: [ super greet ].
    c := Child derive.
    c greet
    """)
    check(result[1].len == 0)
    check(result[0][^1].toString() == "Hello from parent")

  test "super works with >> syntax":
    let result = interp.evalStatements("""
    Parent := Dictionary derive.
    Parent>>greet [ "Hello from parent" ].
    Child := Parent derive.
    Child>>greet [ super greet ].
    c := Child derive.
    c greet
    """)
    check(result[1].len == 0)
    check(result[0][^1].toString() == "Hello from parent")

  test "super chains through multiple levels":
    let result = interp.evalStatements("""
    GrandParent := Dictionary derive.
    GrandParent>>greet [ "Hello from grandparent" ].
    Parent := GrandParent derive.
    Parent>>greet [ super greet ].
    Child := Parent derive.
    Child>>greet [ super greet ].
    c := Child derive.
    c greet
    """)
    check(result[1].len == 0)
    check(result[0][^1].toString().contains("grandparent"))

suite ">> Method Definition Syntax":
  var interp: Interpreter

  setup:
    interp = newInterpreter()
    initGlobals(interp)
    initSymbolTable()

  test ">> defines unary method":
    let result = interp.evalStatements("""
    Person := Dictionary derive.
    Person>>greet [ "Hello, World!" ].
    p := Person derive.
    p greet
    """)
    check(result[1].len == 0)
    check(result[0][^1].toString() == "Hello, World!")

  test ">> defines keyword method with parameters":
    let result = interp.evalStatements("""
    Person := Dictionary derive.
    Person>>name: aName [ aName ].
    p := Person derive.
    p name: "Alice"
    """)
    check(result[1].len == 0)
    check(result[0][^1].toString() == "Alice")

  test ">> defines multi-part keyword method":
    let result = interp.evalStatements("""
    Point := Dictionary derive.
    Point>>moveX: x y: y [ x + y ].
    p := Point derive.
    p moveX: 3 y: 4
    """)
    check(result[1].len == 0)
    check(result[0][^1].toString() == "7")

  test ">> method returns correct value":
    let result = interp.evalStatements("""
    Obj := Dictionary derive.
    Obj>>getValue [ 42 ].
    o := Obj derive.
    o getValue
    """)
    check(result[1].len == 0)
    check(result[0][^1].toString() == "42")
