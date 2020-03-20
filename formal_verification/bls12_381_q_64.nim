##  Autogenerated
##  curve description: test
##  requested operations: (all)
##  m = 0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab (from "0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab")
##  machine_wordsize = 64 (from "64")
##
##  NOTE: In addition to the bounds specified above each function, all
##    functions synthesized for this Montgomery arithmetic require the
##    input to be strictly less than the prime modulus (m), and also
##    require the input to be in the unique saturated representation.
##    All functions also ensure that these two properties are true of
##    return values.

{.compile: "bls12_381_q_64.c".}

type
  fiat_bls12_381_q_uint1*{.importc.} = cuchar
  fiat_bls12_381_q_int1*{.importc.} = cchar
  fiat_bls12_381_q_int128*{.importc.} = object
  fiat_bls12_381_q_uint128*{.importc.} = object

  BLSNumber = array[6, uint64]

func fiat_bls12_381_q_mul*(r: var BLSNumber, a, b: BLSNumber) {.importc.}
  ## Mongomery Mul
func fiat_bls12_381_q_square*(r: var BLSNumber, a: BLSNumber) {.importc.}
  ## Mongomery Square
func fiat_bls12_381_q_add*(r: var BLSNumber, a, b: BLSNumber) {.importc.}
  ## Modular Add
func fiat_bls12_381_q_sub*(r: var BLSNumber, a, b: BLSNumber) {.importc.}
  ## Modular Sub
func fiat_bls12_381_q_opp*(r: var BLSNumber, a: BLSNumber) {.importc.}
  ## Modular Negate
func fiat_bls12_381_q_from_montgomery*(r: var BLSNumber, a: BLSNumber) {.importc.}
  ## Montgomery to Canonical
func fiat_bls12_381_q_to_bytes*(r: var array[48, byte], a: BLSNumber) {.importc.}
  ## Montgomery to Little-Endian
func fiat_bls12_381_q_from_bytes*(r: var BLSNumber, a: array[48, byte]) {.importc.}
  ## Little-Endian to Montgomery

# Hex conversion
# -------------------------------------------------------------------------

func readHexChar(c: char): uint8 {.inline.}=
  ## Converts an hex char to an int
  ## CT: leaks position of invalid input if any.
  case c
  of '0'..'9': result = uint8 ord(c) - ord('0')
  of 'a'..'f': result = uint8 ord(c) - ord('a') + 10
  of 'A'..'F': result = uint8 ord(c) - ord('A') + 10
  else:
    raise newException(ValueError, $c & "is not a hexadecimal character")

func skipPrefixes(current_idx: var int, str: string, radix: static range[2..16]) {.inline.} =
  ## Returns the index of the first meaningful char in `hexStr` by skipping
  ## "0x" prefix
  ## CT:
  ##   - leaks if input length < 2
  ##   - leaks if input start with 0x, 0o or 0b prefix

  if str.len < 2:
    return

  assert current_idx == 0, "skipPrefixes only works for prefixes (position 0 and 1 of the string)"
  if str[0] == '0':
    case str[1]
    of {'x', 'X'}:
      assert radix == 16, "Parsing mismatch, 0x prefix is only valid for a hexadecimal number (base 16)"
      current_idx = 2
    of {'o', 'O'}:
      assert radix == 8, "Parsing mismatch, 0o prefix is only valid for an octal number (base 8)"
      current_idx = 2
    of {'b', 'B'}:
      assert radix == 2, "Parsing mismatch, 0b prefix is only valid for a binary number (base 2)"
      current_idx = 2
    else: discard

func countNonBlanks(hexStr: string, startPos: int): int =
  ## Count the number of non-blank characters
  ## ' ' (space) and '_' (underscore) are considered blank
  ##
  ## CT:
  ##   - Leaks white-spaces and non-white spaces position
  const blanks = {' ', '_'}

  for c in hexStr:
    if c in blanks:
      result += 1

func fromHex(output: var openArray[byte], hexStr: string, order: static[Endianness]) =
  ## Read a hex string and store it in a byte array `output`.
  ## The string may be shorter than the byte array.
  ##
  ## The source string must be hex big-endian.
  ## The destination array can be big or little endian
  var
    skip = 0
    dstIdx: int
    shift = 4
  skipPrefixes(skip, hexStr, 16)

  const blanks = {' ', '_'}
  let nonBlanksCount = countNonBlanks(hexStr, skip)

  let maxStrSize = output.len * 2
  let size = hexStr.len - skip - nonBlanksCount

  doAssert size <= maxStrSize, "size: " & $size & " (without blanks or prefix), maxSize: " & $maxStrSize

  if size < maxStrSize:
    # include extra byte if odd length
    dstIdx = output.len - (size + 1) div 2
    # start with shl of 4 if length is even
    shift = 4 - size mod 2 * 4

  for srcIdx in skip ..< hexStr.len:
    if hexStr[srcIdx] in blanks:
      continue

    let nibble = hexStr[srcIdx].readHexChar shl shift
    when order == bigEndian:
      output[dstIdx] = output[dstIdx] or nibble
    else:
      output[output.high - dstIdx] = output[output.high - dstIdx] or nibble
    shift = (shift + 4) and 4
    dstIdx += shift shr 2

# -------------------------------------------------------------------------

when isMainModule:
  import random, std/monotimes, times, strformat, ../helpers/timers

  const Iters = 1_000_000
  const InvIters = 1000

  randomize(1234)

  # warmup
  proc warmup*() =
    # Warmup - make sure cpu is on max perf
    let start = cpuTime()
    var foo = 123
    for i in 0 ..< 300_000_000:
      foo += i*i mod 456
      foo = foo mod 789

    # Compiler shouldn't optimize away the results as cpuTime rely on sideeffects
    let stop = cpuTime()
    echo &"\n\nWarmup: {stop - start:>4.4f} s, result {foo} (displayed to avoid compiler optimizing warmup away)\n"

  warmup()

  echo "\n⚠️ Measurements are approximate and use the CPU nominal clock: Turbo-Boost and overclocking will skew them."
  echo "==========================================================================================================\n"

  proc report(op, field: string, start, stop: MonoTime, startClk, stopClk: int64, iters: int) =
    echo &"{op:<15} {field:<15} {inNanoseconds((stop-start) div iters):>9} ns {(stopClk - startClk) div iters:>9} cycles"

  proc addBench() =
    var aBytes, bBytes: array[48, byte]
    # BN254 field modulus
    aBytes.fromHex("0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47", littleEndian)
    # BLS12-381 prime - 2
    bBytes.fromHex("0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaa9", littleEndian)

    var r, a, b: BLSNumber

    a.fiat_bls12_381_q_from_bytes(aBytes)
    b.fiat_bls12_381_q_from_bytes(bBytes)

    let start = getMonotime()
    let startClk = getTicks()
    for _ in 0 ..< Iters:
      r.fiat_bls12_381_q_add(a, b)
    let stopClk = getTicks()
    let stop = getMonotime()
    report("Addition", "FiatCrypto[BLS12_381]", start, stop, startClk, stopClk, Iters)

  addBench()

  proc subBench() =
    var aBytes, bBytes: array[48, byte]
    # BN254 field modulus
    aBytes.fromHex("0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47", littleEndian)
    # BLS12-381 prime - 2
    bBytes.fromHex("0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaa9", littleEndian)

    var r, a, b: BLSNumber

    a.fiat_bls12_381_q_from_bytes(aBytes)
    b.fiat_bls12_381_q_from_bytes(bBytes)

    let start = getMonotime()
    let startClk = getTicks()
    for _ in 0 ..< Iters:
      r.fiat_bls12_381_q_add(a, b)
    let stopClk = getTicks()
    let stop = getMonotime()
    report("Substraction", "FiatCrypto[BLS12_381]", start, stop, startClk, stopClk, Iters)

  subBench()

  proc negBench() =
    var aBytes: array[48, byte]
    # BN254 field modulus
    aBytes.fromHex("0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47", littleEndian)

    var r, a: BLSNumber
    a.fiat_bls12_381_q_from_bytes(aBytes)

    let start = getMonotime()
    let startClk = getTicks()
    for _ in 0 ..< Iters:
      r.fiat_bls12_381_q_opp(a)
    let stopClk = getTicks()
    let stop = getMonotime()
    report("Negation", "FiatCrypto[BLS12_381]", start, stop, startClk, stopClk, Iters)

  negBench()

  proc mulBench() =
    var aBytes, bBytes: array[48, byte]
    # BN254 field modulus
    aBytes.fromHex("0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47", littleEndian)
    # BLS12-381 prime - 2
    bBytes.fromHex("0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaa9", littleEndian)

    var r, a, b: BLSNumber

    a.fiat_bls12_381_q_from_bytes(aBytes)
    b.fiat_bls12_381_q_from_bytes(bBytes)

    let start = getMonotime()
    let startClk = getTicks()
    for _ in 0 ..< Iters:
      r.fiat_bls12_381_q_mul(a, b)
    let stopClk = getTicks()
    let stop = getMonotime()
    report("Multiplication", "FiatCrypto[BLS12_381]", start, stop, startClk, stopClk, Iters)

  mulBench()

  proc sqrBench() =
    var aBytes: array[48, byte]
    # BN254 field modulus
    aBytes.fromHex("0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47", littleEndian)

    var r, a: BLSNumber
    a.fiat_bls12_381_q_from_bytes(aBytes)

    let start = getMonotime()
    let startClk = getTicks()
    for _ in 0 ..< Iters:
      r.fiat_bls12_381_q_square(a)
    let stopClk = getTicks()
    let stop = getMonotime()
    report("Squaring", "FiatCrypto[BLS12_381]", start, stop, startClk, stopClk, Iters)

  sqrBench()

  # TODO: No inversion bench
