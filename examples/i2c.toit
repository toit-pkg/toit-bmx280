// Copyright (C) 2021 Toitware ApS. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import i2c
import bmx280

main:
  bus := i2c.Bus
    --sda=21
    --scl=22

  // The BMP280 and BME280 can be configured to have one of two different addresses.
  // - bmx280.I2C-ADDRESS, equal to 0x76.
  // - bmx280.I2C-ADDRESS-ALT, equal to 0x77.
  // The address is generally chosen by the break-out board.
  // If the example fails with I2C_READ_FAILED verify that you are using the correct address.
  address := bmx280.I2C-ADDRESS
  device := bus.device address

  driver := bmx280.Driver device

  print "$driver.read-temperature C"
  print "$driver.read-pressure Pa"
  if driver.has-humidity:
    print "$driver.read-humidity %"
