# EtherENC Hardware

The hardware design has not been finalised (though a working prototype exists).
The basic schematic has been laid out, but board designs are still a work in
progress. Hopefully this document and the schematic will aid in understanding
the method to my madness.

## Key Components

Ethernet Controller: [Microchip
ENC624J600](https://ww1.microchip.com/downloads/en/devicedoc/39935b.pdf)

Flash ROM: [Microchip
SST39SF010](https://ww1.microchip.com/downloads/en/DeviceDoc/20005022C.pdf)

Glue logic CPLD: [Atmel
ATF1502](https://ww1.microchip.com/downloads/en/DeviceDoc/Atmel-0995-CPLD-ATF1502AS(L)-Datasheet.pdf)

## DIY-ability

A major intent of this project is to be low-cost and DIY-assemblable by the
skilled amateur, without any expensive tools or exotic skills. This is
constrained somewhat by the fact that the ENC624J600 and ATF1502 are only
available in surface-mount packages, but nevertheless they can still be
hand-soldered with good-quality flux, desoldering braid, and some practice.

Since surface-mount components were going to be involved anyway, I have gone
ahead and made everything surface mount, but avoided any unreasonably-tiny
footprints - the passives are all 0603 or larger. The trickiest part is the
ENC624J600 (a TQFP-44 with 0.5mm pin pitch), but there is no easier alternative.

Programming the ATF1502 requires a JTAG interface of some sort, however these
can be had very cheaply, and most can be driven by the free OpenOCD suite. Once
the ATF1502 is programmed, the flash ROM can be programmed in-system from RISC
OS, and this repo includes a simple BASIC program to do this.

## Data Width

The basic hardware design is intended to support both 16-bit standard Podules,
and the 8-bit 'mini Podules' used in the A3000, A4000 and A3010, with only minor
changes (configuration strapping of the ENC624J600, and paging of the buffer
RAM). Software handling of the two cards will differ, and 8 bit support has not
been implemented or tested yet, but much of the driver logic should be
applicable to both.

## Memory Map

| Mode     | Address range                    | Read/Write       | Width             | Description                                           |
| -------- | -------------------------------- | ---------------- | ----------------- | ----------------------------------------------------- |
| IOC Fast | `0000-1FFF`                      | R/W <sup>1</sup> | 8                 | Paged access to flash ROM <sup>2</sup>                |
| IOC Fast | `2000` (shadowed through `23FF`) | R                | 8                 | IRQ status register                                   |
| IOC Fast | `2000` (shadowed through `23FF`) | W                | 8                 | Paging latch for ROM and buffer RAM                   |
| IOC Fast | `2400-37FF`                      | -                | -                 | Unused <sup>3</sup>                                   |
| IOC Fast | `3800-3FFF`                      | R/W              | 8/16 <sup>4</sup> | ENC624J600 registers <sup>5</sup>                     |
| MEMC     | `0000-3FFF`                      | R/W              | 8/16 <sup>4</sup> | Paged access to ENC624J600 address space <sup>6</sup> |

**Note 1:** Flash ROM is not directly writeable, but can be erased and
re-written with 'magic' write sequences. See `WriteROM`'s BASIC source for an
example implementation.

**Note 2:** 64 pages of 2048 bytes for 16 bit cards, 32 pages for 8 bit cards.

**Note 3:** Unused space is intended to accommodate the future inclusion of an
IanS-style IDE interface.

**Note 4:** Configurable by strapping pins.

**Note 5:** 256 16-bit registers for 16 bit cards, or 512 8-bit registers for
8-bit cards.

**Note 6:** 4 pages of 4096 halfwords for 16-bit cards, or 4 pages of 4096 bytes
for 8-bit cards (covering only top half of ENC624J600 address space in 8-bit mode).

### IRQ Status Register

The ENC624J600 puts its main IRQ status bit in bit 15 of its status register. On
16-bit cards, this renders it inaccessible to RISC OS' Podule IRQ routines, as
they use `LDRB` to read the status register, and Podules do not allow arbitrary
byte access.

To work around this, an IRQ status register is implemented at address `0x2000`:

| Bit | Description               |
| --- | ------------------------- |
| 0   | Card is asserting `/PIRQ` |
| 1-7 | Unimplemented, reserved   |

### Paging Latch

Paging for both ROM and the ENC624J600's address space is controlled by a
write-only latch at `0x2000`. Paging of the ENC624J600 address space is
controlled through the `Podule_CallLoader` SWI so as to allow these two paging
functions to coexist in a single register.

Paging bits are mapped as follows:

| Bit | ROM | ENC624J600 <sup>1</sup> |
| --- | --- | ----------------------- |
| 0   | A11 | -                       |
| 1   | A12 | -                       |
| 2   | A13 | -                       |
| 3   | A14 | -                       |
| 4   | A15 | -                       |
| 5   | A16 | -                       |
| 6   | -   | A12                     |
| 7   | -   | A13                     |

**Note 1:** In 16-bit mode, the ENC624J600's address pins correspond to halfword
addresses, rather than byte addresses.

Note that for 8-bit cards, there are insufficient paging bits to access the
entirety of the ENC624J600's memory. Address line A14 (unused in 16 bit mode) is
tied high, restricting paged access to the top 16K of the ENC624J600's address
space. This effectively prevents direct paged access to buffer memory, requiring
use of the ENC624J600's indirection registers instead.

## Theory of Operation

The ENC624J600 has a 32KB address space, providing 24KB of onboard buffer SRAM,
and a register bank at the top of its address space. In 16-bit mode, this
address space is laid out as 16K 16-bit halfwords. In 8-bit mode, an additional
address line is used, and access is as 32K 8-bit bytes. Due to the limitaitons
of the Podule bus, individual byte addressing in 16-bit mode is *not* possible. 

A commodity RJ45 jack with integrated magnetics and LEDs is used to simplify the
design. ROM is provided by an SST39SF010 128kx8 flash memory, which can be
programmed in-system using an included BASIC utility. Control and timing logic
is all implemented within an ATF1502 CPLD. An 8-bit latch provides a write-only
paging register, controlling paging of both ROM and the ENC624J600's address
space.

The ENC624J600 can be addressed in two 'modes', goverened by an address buffer
under control of the ATF1502. When `ETH_/PAGE` is asserted, the full complement
of Podule address bits (`LA13`..`LA2`), plus two paging-latch bits
(`ETH_PG1`..`ETH_PG0`) cover the full address space of the ENC624J600 in 16 bit
mode <sup>1</sup>. This is used for MEMC mode accesses to the ENC624J600's
buffer RAM. When `ETH_/PAGE` is not asserted, the high bits of the ENC624J600's
address bus are undriven and pulled high, exposing only the register space. This
mode is used to expose just the ENC624J600's registers in IOC space at
`3800-38FF`.

The ENC624J600 is a 3.3V device, with 5V-tolerant I/O. Its 3.3V supply is
provided by an onboard LDO regulator. In future hardware revisions, a regulator
with an Enable input under control of the ATF1502. This will be used to work
around the ENC624J600's lack of a hardware reset pin, by power-on-resetting the
chip when the Podule `/RST` line is asserted.

All components are tolerant of 500ns 'fast' accesses (and all slower access
modes too). 250ns timing is used for MEMC-space accesses to the ENC624J600,
equivalent to a RAM 'N-cycle'. `LDM`/`STM` to ENC624J600 RAM through MEMC space
is supported, though timing remains at 250ns throughout, MEMC does not appear to
support S-cycles to I/O devices.

**Note 1:** On 8-bit cards, only the upper 16K of the ENC624J600's address space
is accessible in paged mode.

## Loader SWI interface

Due to the shared write-only nature of the paging register, access must be
coordinated through the loader interface to avoid disruption. Access to ROM must
go through standard RISC OS SWIs (`Podule_ReadBytes`, `Podule_ReadChunk` etc.),
and paging of the ENC624J600 address space must be controlled through the
`Podule_CallLoader` SWI as described below. This has the beneficial side effect
of providing an abstraciton layer over the different paging-bit assignments of
8- and 16-bit cards.

To accommodate changes in future hardware revisions, `Podule_CallLoader` is also
used to control power and interrupt-gating functions:

| R0 (reason code) | Function                                | R1 (argument) |
| ---------------- | --------------------------------------- | ------------- |
| 0                | Set ENC624J600 page                     | Page number   |
| 1                | Power-on ENC624J600 (currently a no-op) | Unused        |
| 2                | Un-gate ENC624J600 IRQs                 | Unused        |

## Power Control and Interrupt Gating

The ENC624J600 has no hardware reset pin - it can be reset only by power-cycling
it, or writing to a control register. The driver resets the ENC624J600 at module
exit, and does the same if it receives a `PreReset` service call, but if the
machine crashes or is reset abruptly, the ENC624J600 will be left in a
potentially interrupt-generating state.

The current hardware mitigates this by gating interrupts until the driver
indicates that it is in control, via the SWI interface described above. Future
revisions will additionally control the power to the ENC624J600, allowing it to
be fully reset through a power-cycle when the system is reset.

The driver must initialise the chip as follows (based on section 8.1 of the
ENC624J600 data sheet):

1. Call the `Podule_CallLoader` SWI for the appropriate slot, with R0 = 1.

2. Wait 25 microseconds for the ENC624J600 to come out of power-on reset.

3. Write `0x1234` to the EUDAST register and read it back, repeating until it
   reads back correctly.

4. Wait for the CLKRDY bit of the ESTAT register to be set.

5. Set the ETHRST bit of the ECON2 register.

6. Wait 25 microseconds for the ENC624J600 to come out of soft-reset.

7. Read the EUDAST register and ensure it has reset to `0x0000`.

8. Call the `Podule_CallLoader` SWI for the appropriate slot, with R0 = 2.

9. Wait 256 microseconds for the PHY to finish initialising.

## IDE Interface

As mentioned above, the address range `2400-37FF` is decoded, but left unmapped.
The intention is for future versions of this card to use this space for an IDE
interface - this is particularly desirable for the 8-bit version of the card, as
it would allow single-slot machines such as the A4000 and A3010 to have both IDE
and ethernet.

This gap in the address range is designed to accomodate the register map of the
popular 'IanS' IDE interfaces (both 8- and 16-bit variants). While IDE drivers
such as ZIDEFS will need to be modified to recognise the podule ID of a combined
Ethernet/IDE card, they should otherwise be software-compatible.

## Mechanical design

One remaining item to be resolved, is the design of back-panel brackets for
full-size and mini-podules. Fabrication out of sheet-metal is probably
cost-prohibitive, but it should be possible to 3D-print acceptable substitutes,
using Acorn's drawings as a guide.
