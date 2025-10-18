# ENC624J600-based Ethernet card for Acorn Archimedes and Risc PC systems

From the same person who still hasn't quite finished
[SEthernet](https://github.com/rhalkyard/SEthernet), comes yet another Ethernet
card for vintage computers!

Ethernet cards for Acorn systems are even harder to find than for vintage Macs.
This project is an attempt to bring a modern, low-cost Ethernet card to Acorn
Archimedes and Risc PC machines.

## Project Status

Early days yet! I have the driver functioning on a prototype version of the
card, but enough bodges were necessary with the prototype hardware that I do not
feel comfortable releasing it in its present form. Once the revised design is
finalised, schematics and board layouts will be made available in this repo.

## Supported Systems

The intent is for this card to be compatible with any RISC OS machine with 16-
or 8-bit Podule slots, running RISC OS 3.10 or later. However, I only have
access to an A3000, so testing on later OSes and other machines will be up to
others!

## Hardware

See [HARDWARE.md](hardware.md) for a design overview.

Schematic in PDF format can be found at
[pcb/EtherENC-prototype/EtherENC-Prototype.pdf](pcb/EtherENC-prototype/EtherENC-Prototype.pdf).

## Software

The [EtherENC/](EtherENC) directory contains driver source, buildable with Acorn
C/C++ version 5, which can be obtained from
[https://www.4corn.co.uk/articles/acornc5/](https://www.4corn.co.uk/articles/acornc5/),
or included in [RPCEMU](https://www.marutan.net/rpcemu/index.php)'s RISC OS 3.71
Easy-Start bundle.

If you are not used to RISC OS, the filenames and layout will look a little
weird. Instead of having extensions, `.c` and `.h` files live in separate
directories, and the comma-suffixes on various file names encode RISC OS file
types. Of particular interest, the `,ffb` files are BBC Basic programs, however
these are stored in a binary format and their source is not easily viewable on
non-RISC OS systems. Accompanying text dumps of the program code are included
alongside, I will endeavour to keep these up to date.

`MkROM` is a BASIC program that builds the card's ROM image with the appropriate
headers and loadable driver module.

`WriteROM` can then be used to program or update the card's flash with the new
ROM image.

### Building

1. Install Acorn C/C++ and run `!SetPaths` inside the Acorn C/C++ directory.

2. Run the `!Mk` script in the source directory (or run `amu` from a TaskWindow
   or CLI).

### Flashing

1. After building the EtherENC driver, run `WriteROM` and follow the prompts.

### Installation

These instructions assume that you are using the version of `!Internet` included
in the Universal !Boot distribution. If you are using something else, you should
probably be able to figure out how to adapt them to your setup!

1. Copy `AutoSense.EtherENC` to
   `!Boot.Resources.Configure.!InetSetup.AutoSense`.

2. (optional) Copy the built `EtherENC` module to
   `!Boot.Resources.System.Modules.Network`. The driver module from the card ROM
   should be sufficient, but when testing it can be useful to softload the
   module instead.

3. Restart RISC OS.

### Configuring

Configuring the card is more or less the same as any other network interface on
RISC OS, and is done by the `!Boot.Resources.Configure.!InetSetup` application:

1. Run `!Boot.Resources.Configure.!InetSetup`, and click the `Internet` icon.

2. Under `Interfaces`, tick the box next to `EtherENC`, click the adjacent
   `Configure...` button, and set your IP address and netmask. Unless you know
   what you're doing, `Obtain IP address` should be set to `Manually`, and
   `Primary interface` should be ticked.

2. Under `Routing`, enter your default gateway. Unless you know what you're
   doing, `Act as an IP router` and `Run RouteD` should not be ticked.

3. Under `Host names`, ether your hostname domain, and DNS server(s). Ensure
   that `Use name servers also` is selected.

4. Configure AUN and Access if necessary (doing so is beyond the scope of this
   document).

#### CMOS Settings

The system's CMOS memory is used to store hardware configuration options across
reboots. These options can be set and read using RISC OS' `*Configure` and
`*Status` commands.

`*Configure ENCFlow <unit> Off|On` - Enable or disable PAUSE-frame flow control,
which may help mitigate packet drops on heavily-loaded systems. Default is
`Off`. Flow control can only operate on full-duplex links.

`*Configure ENCLink <unit> Auto | 10 Half|Full | 100 Half|Full` - Configure link
mode. `Auto` (the default) causes link speed and duplex mode to be
autonegotiated with the link partner. Otherwise, a fixed speed and duplex
setting (one of `10 Half`, `10 Full`, `100 Half` or `100 Full`) can be set.

After installing the card, or moving it into another slot, it may be necessary
to reconfigure the card in order to overwrite any leftover CMOS settings from
previous residents of that slot. Defaults can be restored with:

```
*Configure ENCLink <unit> Auto
*Configure ENCFlow <unit> Off
```

## Licenses

Hardware (everything in the `pcb` and `pld` directories) is licensed under the
CERN Open Hardware License Version 2 - Strongly Reciprocal.

The driver (everything in the `EtherENC` directory) is licensed under the GNU
Public License Version 3, with the following exceptions:

- `EtherENC.h.syslog` and `EtherENC.s.syslog` are included unmodified from the
  SysLog freeware application (https://compton.nu/software/riscos/syslog).

- The contents of `EtherENC.TCPIPLibs` is from the `sockets.arc` archive, as
  distributed on Acorn's FTP site. Ownership and licensing of this is unclear.

## To Do

- Finalise hardware design

- Performance testing and driver optimisation


## References

- [RISC OS 3 Programmer's Reference Manual](http://www.riscos.com/support/developers/prm/)

- [Acorn Enhanced Expansion Card
  Specification](https://www.chiark.greenend.org.uk/~theom/riscos/docs/expspec.pdf)

- [RISC OS DCI4 Reference Manuals](https://gerph.github.io/riscos-prm-dci4/)

- [Ether1 (AMD LANCE-based card) driver source](https://gitlab.riscosopen.org/RiscOS/Sources/Networking/Ethernet/Ether1)

- [EtherY (LAN91C111-based card) driver source](https://gitlab.riscosopen.org/RiscOS/Sources/Networking/Ethernet/EtherY/)
