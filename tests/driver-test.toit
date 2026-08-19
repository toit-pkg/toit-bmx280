// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be found
// in the LICENSE file.

import expect show *
import io
import serial.device as serial
import serial.registers as serial

import bmx280

CHIP-ID-REGISTER_       ::= 0xD0
RESET-REGISTER_         ::= 0xE0
CONTROL-HUM-REGISTER_   ::= 0xF2
STATUS-REGISTER_        ::= 0xF3
CONTROL-MEAS-REGISTER_  ::= 0xF4
PRESSURE-DATA-REGISTER_ ::= 0xF7
TEMPERATURE-DATA-REGISTER_ ::= 0xFA
HUMIDITY-DATA-REGISTER_ ::= 0xFD

class FakeRegisters extends serial.Registers:
  memory_/ByteArray := ByteArray 256
  reads/List := []
  writes/List := []

  read-bytes register/int count/int -> ByteArray:
    reads.add [register, count]
    return memory_[register..register + count]

  write-bytes register/int data/ByteArray -> none:
    writes.add [register, data.copy]
    memory_.replace register data

  set-u8 register/int value/int -> none:
    memory_[register] = value

  set-i8 register/int value/int -> none:
    memory_[register] = value & 0xff

  set-u16-le register/int value/int -> none:
    io.LITTLE-ENDIAN.put-uint16 memory_ register value

  set-i16-le register/int value/int -> none:
    io.LITTLE-ENDIAN.put-int16 memory_ register value

  set-u16-be register/int value/int -> none:
    io.BIG-ENDIAN.put-uint16 memory_ register value

  set-u24-be register/int value/int -> none:
    io.BIG-ENDIAN.put-uint24 memory_ register value

  read-count register/int -> int:
    count := 0
    reads.do: | entry/List |
      if entry[0] == register: count++
    return count

  write-count register/int -> int:
    count := 0
    writes.do: | entry/List |
      if entry[0] == register: count++
    return count

  last-write register/int -> int?:
    writes.size.repeat:
      entry/List := writes[writes.size - it - 1]
      if entry[0] == register: return entry[1][0]
    return null

class FakeDevice implements serial.Device:
  registers/FakeRegisters

  constructor .registers:

  read amount/int -> ByteArray:
    throw "UNIMPLEMENTED"

  write bytes/ByteArray -> none:
    throw "UNIMPLEMENTED"

main:
  test-probe
  test-bmp280
  test-bme280

test-probe:
  bmp := fake-device_ bmx280.CHIP-ID-BMP280
  expect-equals bmx280.CHIP-ID-BMP280 (bmx280.probe bmp)

  bme := fake-device_ bmx280.CHIP-ID-BME280
  expect-equals bmx280.CHIP-ID-BME280 (bmx280.probe bme)

  invalid := fake-device_ 0xff
  expect-throw "INVALID_CHIP": bmx280.probe invalid
  expect-equals 5 (invalid.registers.read-count CHIP-ID-REGISTER_)

test-bmp280:
  device := fake-device_ bmx280.CHIP-ID-BMP280
  driver := bmx280.Driver device

  expect-equals bmx280.CHIP-ID-BMP280 driver.chip-id
  expect-not driver.has-humidity
  expect-equals 0 (device.registers.read-count 0xA1)
  expect-equals 0 (device.registers.read-count 0xE1)
  expect-equals 0 (device.registers.write-count CONTROL-HUM-REGISTER_)
  expect-equals 1 (device.registers.write-count RESET-REGISTER_)
  expect-throw "HUMIDITY_NOT_SUPPORTED": driver.read-humidity

  expect-close_ 25.08 driver.read-temperature 0.001
  expect-close_ 100_653.25 driver.read-pressure 0.01

test-bme280:
  device := fake-device_ bmx280.CHIP-ID-BME280
  driver := bmx280.Driver device

  expect-equals bmx280.CHIP-ID-BME280 driver.chip-id
  expect driver.has-humidity
  expect-equals 1 (device.registers.read-count 0xA1)
  expect-equals 1 (device.registers.read-count 0xE1)
  expect-equals 1 (device.registers.write-count CONTROL-HUM-REGISTER_)
  expect-equals 1 (device.registers.last-write CONTROL-HUM-REGISTER_)

  expect-close_ 25.08 driver.read-temperature 0.001
  expect-close_ 100_653.25 driver.read-pressure 0.01
  humidity := driver.read-humidity
  expect 0.0 <= humidity <= 100.0

fake-device_ chip-id/int -> FakeDevice:
  registers := FakeRegisters
  registers.set-u8 CHIP-ID-REGISTER_ chip-id
  registers.set-u8 STATUS-REGISTER_ 0

  // Calibration values and uncompensated readings from the BMP280 data sheet.
  registers.set-u16-le 0x88 27_504
  registers.set-i16-le 0x8A 26_435
  registers.set-i16-le 0x8C -1_000
  registers.set-u16-le 0x8E 36_477
  registers.set-i16-le 0x90 -10_685
  registers.set-i16-le 0x92 3_024
  registers.set-i16-le 0x94 2_855
  registers.set-i16-le 0x96 140
  registers.set-i16-le 0x98 -7
  registers.set-i16-le 0x9A 15_500
  registers.set-i16-le 0x9C -14_600
  registers.set-i16-le 0x9E 6_000

  // Representative BME280 humidity calibration values.
  registers.set-u8 0xA1 75
  registers.set-i16-le 0xE1 362
  registers.set-u8 0xE3 0
  registers.set-i8 0xE4 0x14
  registers.set-u8 0xE5 0x25
  registers.set-i8 0xE6 0x03
  registers.set-i8 0xE7 30

  registers.set-u24-be PRESSURE-DATA-REGISTER_ (415_148 << 4)
  registers.set-u24-be TEMPERATURE-DATA-REGISTER_ (519_888 << 4)
  registers.set-u16-be HUMIDITY-DATA-REGISTER_ 30_000

  return FakeDevice registers

expect-close_ expected/float actual/float tolerance/float -> none:
  difference := expected - actual
  if difference < 0: difference = -difference
  expect difference <= tolerance
