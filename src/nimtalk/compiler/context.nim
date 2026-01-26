import std/[tables, sequtils]
import ./types

# ============================================================================
# Compiler Context
# Maintains state during Nimtalk to Nim compilation
# ============================================================================

type
  SlotDef* = object
    name*: string              ## Slot name
    constraint*: TypeConstraint ## Type constraint
    index*: int                ## Slot index (O(1) access)
    isInherited*: bool         ## Inherited from parent

  MethodType* = object
    selector*: string          ## Method selector
    parameters*: seq[TypeConstraint]  ## Parameter type constraints
    returnType*: TypeConstraint ## Return type constraint
    isPrimitive*: bool         ## Has primitive implementation

  PrototypeInfo* = ref object
    name*: string              ## Prototype name
    parent*: PrototypeInfo     ## Parent prototype (prototype chain)
    slots*: seq[SlotDef]       ## Slot definitions
    methods*: seq[MethodType]  ## Method type information
    slotIndex*: Table[string, int]  ## Slot name -> index

  CompilerContext* = ref object
    outputDir*: string
    moduleName*: string
    prototypes*: Table[string, PrototypeInfo]  ## Prototype registry
    currentProto*: PrototypeInfo  ## Currently compiling prototype
    symbols*: Table[string, string]  ## Selector -> mangled name
    generatedMethods*: seq[tuple[selector: string, code: string]]

proc newCompiler*(outputDir = "./build", moduleName = "compiled"): CompilerContext =
  ## Create new compiler context
  result = CompilerContext(
    outputDir: outputDir,
    moduleName: moduleName,
    prototypes: initTable[string, PrototypeInfo](),
    currentProto: nil,
    symbols: initTable[string, string](),
    generatedMethods: @[]
  )

proc newPrototypeInfo*(name: string, parent: PrototypeInfo = nil): PrototypeInfo =
  ## Create new prototype info
  result = PrototypeInfo(
    name: name,
    parent: parent,
    slots: @[],
    methods: @[],
    slotIndex: initTable[string, int]()
  )

proc addSlot*(proto: PrototypeInfo, name: string,
              constraint: TypeConstraint = tcObject): int =
  ## Add a slot definition and return its index
  if name in proto.slotIndex:
    return proto.slotIndex[name]

  let slot = SlotDef(
    name: name,
    constraint: constraint,
    index: proto.slots.len,
    isInherited: false
  )
  proto.slots.add(slot)
  proto.slotIndex[name] = slot.index
  return slot.index

proc getSlotIndex*(proto: PrototypeInfo, name: string): int =
  ## Get slot index, searching prototype chain
  if name in proto.slotIndex:
    return proto.slotIndex[name]
  if proto.parent != nil:
    return proto.parent.getSlotIndex(name)
  return -1

proc getSlotDef*(proto: PrototypeInfo, name: string): SlotDef =
  ## Get slot definition, searching prototype chain
  if name in proto.slotIndex:
    let idx = proto.slotIndex[name]
    if idx < proto.slots.len and proto.slots[idx].name == name:
      return proto.slots[idx]
  if proto.parent != nil:
    return proto.parent.getSlotDef(name)
  return SlotDef(name: name, constraint: tcNone, index: -1, isInherited: true)

proc addMethod*(proto: PrototypeInfo, selector: string,
                parameters: seq[TypeConstraint],
                returnType: TypeConstraint = tcNone): MethodType =
  ## Add method type information
  let meth = MethodType(
    selector: selector,
    parameters: parameters,
    returnType: returnType,
    isPrimitive: false
  )
  proto.methods.add(meth)
  return meth

proc getMethodType*(proto: PrototypeInfo, selector: string): MethodType =
  ## Get method type info, searching prototype chain
  for meth in proto.methods:
    if meth.selector == selector:
      return meth
  if proto.parent != nil:
    return proto.parent.getMethodType(selector)
  return MethodType(selector: selector, parameters: @[], returnType: tcNone)

proc getAllSlots*(proto: PrototypeInfo): seq[SlotDef] =
  ## Get all slots including inherited ones
  result = @[]
  var current: PrototypeInfo = proto
  while current != nil:
    for slot in current.slots:
      if not slot.isInherited and result.allIt(it.name != slot.name):
        result.add(slot)
    current = current.parent
  # Reverse to put parents first
  var reversedResult: seq[SlotDef] = @[]
  for i in countdown(result.len - 1, 0):
    reversedResult.add(result[i])
  result = reversedResult

proc resolveSlotIndices*(ctx: var CompilerContext): void =
  ## Resolve and assign slot indices across prototype chain
  for name, proto in ctx.prototypes.mpairs:
    proto.slotIndex.clear()
    var idx = proto.parent.getAllSlots().len
    for slot in proto.slots.mitems:
      if not slot.isInherited:
        slot.index = idx
        proto.slotIndex[slot.name] = idx
        inc idx
