# BMX280

Driver for the Bosch BMP280 and BME280 environmental sensors.

Both sensors provide temperature and pressure measurements. The BME280 also
provides relative-humidity measurements. The driver detects the connected model
from its chip ID and only accesses humidity registers when a BME280 is present.

## Installation

```sh
jag pkg install github.com/toit-pkg/toit-bmx280
```

## Direct use

```toit
import i2c
import bmx280

main:
  bus := i2c.Bus --sda=21 --scl=22
  device := bus.device bmx280.I2C-ADDRESS
  sensor := bmx280.Driver device

  print "$sensor.read-temperature C"
  print "$sensor.read-pressure Pa"
  if sensor.has-humidity:
    print "$sensor.read-humidity %"
```

The supported I2C addresses are `I2C-ADDRESS` (`0x76`) and
`I2C-ADDRESS-ALT` (`0x77`). The driver also accepts an SPI device through the
generic `serial.Device` interface.

`Driver.chip-id` identifies the detected sensor as `CHIP-ID-BMP280` or
`CHIP-ID-BME280`. Calling `read-humidity` on a BMP280 throws
`HUMIDITY_NOT_SUPPORTED`.

## Sensor service

`src/provider.toit` exposes the driver through the standard `sensors` package.
The provider probes the sensor during installation and only publishes the
humidity service for a BME280.

The container in `service/main.toit` accepts `scl`, `sda`, and an optional
`address` through its configuration asset. See `service/schema.json` for the
complete schema.

## Testing

```sh
make test
```

The unit tests use an in-memory serial device and run on the host without
physical hardware or QEMU.
