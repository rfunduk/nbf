from std/strutils import repeat, join
from std/os import paramCount, paramStr
from std/syncio import readFile
from system import quit

const MAX_MEM = 30000

const COMMANDS = {'+', '-', '<', '>', '[', ']', '.', ','}
const REPEATABLE_COMMANDS = {'+', '-', '<', '>', '.'}

type BfOp = object of RootObj
  index: uint32
  command: char
  repeatCount: uint8 = 1
  targetIndex: uint16

proc usage() = echo "Usage: nbf <input.bf>"

func preprocess(source: string): string =
  result = ""
  for c in source:
    if COMMANDS.contains(c):
      result &= c

func translate(source: string): seq[BfOp] =
  let sourceLength = source.len
  var jumpsStack: seq[uint16] = @[]
  var opIndex: uint16 = 0
  var ops: seq[BfOp] = @[]

  var i: int = 0
  while i < sourceLength:
    var op = BfOp(
      index: opIndex,
      command: source[i],
    )

    # consume more commands and add to repeatCount
    # if there are multiple in a row.
    # only certain commands are repeatable
    if REPEATABLE_COMMANDS.contains(op.command):
      while true:
        if i+1 >= sourceLength or
           source[i+1] != op.command:
          break
        inc(op.repeatCount)
        inc(i)

    # handling of jumps/loops
    case op.command:
      of '[': jumpsStack.add(opIndex)
      of ']':
        op.targetIndex = jumpsStack.pop
        ops[op.targetIndex].targetIndex = opIndex
      else: discard

    ops.add(op)
    inc(opIndex)
    inc(i)

    # optimise [-] to just zero out the current memory location.
    # to do this we can look at the last 3 commands and
    # see if they match, then remove them and replace with
    # a custom internal command 'z' which does this
    let totalOps = ops.len
    if ops[totalOps-1].command == ']' and
       ops[totalOps-2].command == '-' and
       ops[totalOps-3].command == '[':
      ops = ops[0..totalOps-4]
      dec(opIndex, 3)

      # add 'z' command
      ops.add(BfOp(
        index: opIndex,
        command: 'z',
      ))
      inc(opIndex)

  result = ops

proc execute(ops: seq[BfOp]) =
  var mem = default(array[MAX_MEM, uint8])
  var ip: uint16 = 0 # instruction pointer
  var mp: uint16 = 0 # memory pointer

  while ip < uint16(ops.len):
    var op = ops[ip]
    case op.command:
      of '+': inc(mem[mp], op.repeatCount)
      of '-': dec(mem[mp], op.repeatCount)
      of '>': mp = (mp + op.repeatCount) mod MAX_MEM
      of '<': mp = (mp - op.repeatCount + MAX_MEM) mod MAX_MEM
      of '.': stdout.write(repeat(char(mem[mp]), op.repeatCount))
      of ',': mem[mp] = uint8(stdin.readChar())
      of '[': (if mem[mp] == 0: ip = op.targetIndex)
      of ']': (if mem[mp] != 0: ip = op.targetIndex)
      of 'z': mem[mp] = 0
      else: discard

    inc(ip)

  stdout.write("\n")

if paramCount() != 1: usage(); quit(1)
paramStr(1).readFile.preprocess.translate.execute
