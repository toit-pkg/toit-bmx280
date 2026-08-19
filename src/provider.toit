// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be found
// in the LICENSE file.

import i2c
import sensors.providers

import .driver as bmx280

NAME_ ::= "toit.io/bmx280"
MAJOR_ ::= 1
MINOR_ ::= 0

class Sensor_
    implements
      providers.TemperatureSensor-v1
      providers.HumiditySensor-v1
      providers.PressureSensor-v1:
  i2c_/i2c.Bus? := null
  device_/i2c.Device? := null
  sensor_/bmx280.Driver? := null

  constructor --sda/int --scl/int --address/int:
    is-exception := true
    try:
      i2c_ = i2c.Bus --sda=sda --scl=scl
      device_ = i2c_.device address
      sensor_ = bmx280.Driver device_
      is-exception = false
    finally:
      if is-exception: close

  temperature-read -> float?:
    return sensor_.read-temperature

  humidity-read -> float:
    return sensor_.read-humidity

  pressure-read -> float:
    return sensor_.read-pressure

  close -> none:
    if sensor_:
      sensor_.close
      sensor_ = null
    if device_:
      device_.close
      device_ = null
    if i2c_:
      i2c_.close
      i2c_ = null

/**
Installs a BMP280 or BME280 sensor.

The sensor is probed while installing the provider. A BMP280 provider exposes
  temperature and pressure services. A BME280 provider additionally exposes a
  humidity service.
*/
install --sda/int --scl/int --address/int -> providers.Provider:
  chip-id := probe_ --sda=sda --scl=scl --address=address
  handlers := [providers.TemperatureHandler-v1]
  if chip-id == bmx280.CHIP-ID-BME280:
    handlers.add providers.HumidityHandler-v1
  handlers.add providers.PressureHandler-v1

  provider := providers.Provider NAME_
      --major=MAJOR_
      --minor=MINOR_
      --open=:: Sensor_ --sda=sda --scl=scl --address=address
      --close=:: it.close
      --handlers=handlers
  provider.install
  return provider

probe_ --sda/int --scl/int --address/int -> int:
  bus/i2c.Bus? := null
  device/i2c.Device? := null
  try:
    bus = i2c.Bus --sda=sda --scl=scl
    device = bus.device address
    return bmx280.probe device
  finally:
    if device: device.close
    if bus: bus.close
