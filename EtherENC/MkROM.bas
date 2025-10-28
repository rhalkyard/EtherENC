REM Script to build ethernet card ROM image and loader

REM Default work directory if run directory cannot be determined
REM See FNrundir
defaultdir$ = "@"

REM Filename to output to
filename$ = "ENCRom"

REM Address of ROM paging register relative to slot base
pagereg% = &2000
encbase% = &3800

REM Paging parameters
rom_addrbits% = 11
rom_pagebits% = 6
eth_pagebits% = 2

REM Podule manufacturer and product IDs
REM These are supposed to be assigned to you by Acorn (lol)
mfr_id% = &9635
prod_id% = &3216

REM These are derived quantities and should not need to be edited
REM unless you are doing something weird.
REM ROM page size in bytes
rom_pagesize% = 2^rom_addrbits%
REM Number of ROM pages
rom_npages% = 2^rom_pagebits%
REM Total ROM size in bytes
rom_size% = rom_pagesize% * rom_npages%
REM Number of ethernet pages
eth_npages% = 2^eth_pagebits%
REM Paging register mask for ROM paging
rom_pagemask% = rom_npages%-1
REM Paging register mask for ethernet RAM paging
eth_pagemask% = (eth_npages%-1) << rom_pagebits%

REM ARM status bits
v_bit% = 1<<28
i_bit% = 1<<27
svc_mode% = &3

REM Determine script directory for relative paths
dir$=FNrundir(defaultdir$)

REM Workspace for assembling ROM to
DIM rom% rom_size%

REM Use relocating assembly since expansion card addresses are
REM all relative to the start of the ROM.
FOR pass% = 4 TO 14 STEP 10
O% = rom% : REM Assembly destination
P% = 0 : REM Relocation destination

REM Until we have the loader, everything must fit in 1 page
L% = rom% + rom_pagesize%

[OPT pass%
REM Expansion card header
EQUB 0        : REM ECId
EQUB 2 + 1    : REM 8 bit, chunk dir, interrupt ptrs
EQUB 0        : REM Reserved, must be 0
EQUW prod_id% : REM Product ID
EQUW mfr_id%  : REM Manufacturer ID
EQUB 0        : REM Reserved, must be 0
REM FIQ pointer and mask
EQUD 0
REM IRQ pointer and mask (read bit 0 of paging register)
REM &300000 = fast base
EQUD ((&300000 + pagereg%) << 8) + &01

REM Chunk directory for expansion card space
REM This only needs to contain the loader
FNchunk(&80, chunk_loader, chunkend_loader)
FNchunk(0, 0, 0) : REM End of directory

.chunk_loader
FNloader
ALIGN
.chunkend_loader
]

REM From here on, data is read through the loader, in a logical
REM 'code space' address space that starts from 0 again.
P% = 0 : REM Relocation destination

REM Adjust limit to size of ROM
L% = rom% + rom_size%
[OPT pass%
REM Code space chunk directory
REM This directory MUST NOT be empty or Bad Things will happen
FNchunk(&F2, chunk_date, chunkend_date)
FNchunk(&F3, chunk_mod, chunkend_mod)
FNchunk(&F4, chunk_place, chunkend_place)
FNchunk(&F5, chunk_desc, chunkend_desc)
REM Add modules here, with chunk type &81
FNchunk(&81,chunk_etherenc, chunkend_etherenc)
FNchunk(0,0,0) : REM End of directory

.chunk_date
EQUS TIME$ + CHR$0
.chunkend_date
ALIGN

.chunk_mod
EQUS "Pre-alpha" + CHR$0
.chunkend_mod
ALIGN

.chunk_place
EQUS "St. Paul, Minnesota, USA" + CHR$0
.chunkend_place
ALIGN

.chunk_desc
EQUS "ENC624J600 Ethernet Podule (16 bit)" + CHR$0
.chunkend_desc
ALIGN

.chunk_etherenc
FNincbin(dir$+".EtherENC")
.chunkend_etherenc
ALIGN
]
NEXT pass%

rom_used%=O%-rom%
rom_pagesused=rom_used%/rom_pagesize%
IF INT(rom_pagesused) <> rom_pagesused THEN rom_pagesused=INT(rom_pagesused)+1 : REM Round up
PRINT filename$+": ";rom_used%;" of ";rom_size%;" bytes used (";rom_pagesused;" of "; rom_npages%; "
 pages)"
SYS "OS_File", 10, dir$ + ".ENCRom", &FFD,, rom%, rom%+rom_used%

END

REM Ugly hack to get the directory we're running from so that we
REM can construct paths relative to it.
REM Why does BBC BASIC make this so hard???!?!?!
REM DIMs memory, so should only be called once.
REM dir$=Default directory if run directory not known (@ for CWD)
REM Returns basename of BASIC file being executed
DEF FNrundir(dir$)
LOCAL env$,I%,J%,argbuf%,flags%
DIM argbuf% 255
SYS "OS_GetEnv" TO env$
SYS "XOS_ReadArgs", "BASIC,quit/K",env$,argbuf%,256 TO;flags%
IF NOT (flags% AND 1) AND argbuf%!4 >= 0 THEN
  REM X prefix causes no error to be generated, but has handy side
  REM effect of converting null terminator to BASIC-style CR.
  SYS "XOS_GenerateError",argbuf%!4 TO A$
  REM Path starting with @ indicates running from memory (e.g.
  REM Ctl-Shift-F in !Zap) and is not a valid path
  IF LEFT$(A$,1) <> "@" THEN
    REM Find and remove the leaf name from the path
    J%=0
    REPEAT
      I%=J%
      J%=INSTR(A$,".",I%+1)
    UNTIL J%<1
    dir$=LEFT$(A$,I%-1)
  ENDIF
ENDIF
=dir$

DEF FNlog2(x)=LN(x)/LN(2)

REM Generate a chunk directory entry
DEF FNchunk(type%, start%, end%)
[OPT pass%
EQUD ((end%-start%) << 8) OR type%
EQUD start%
]
=0

REM Read and include a binary file
REM Does NOT check for sufficent space!
DEF FNincbin(name$)
LOCAL size%
SYS "OS_File",255,name$,O%,0 TO ,,,,size%
O%=O%+size%
P%=P%+size%
=0

REM Assemble ROM loader code
REM Implements loader interface as described in PRM. CallLoader
REM SWI is used to control ethernet RAM paging.
DEF FNloader
[OPT pass%
REM Loader entrypoints
  B       loader_read
  B       loader_write
  B       loader_reset
  B       loader_swi

REM Masks to extract slot base from combined address
.fast_mask
  EQUD    &3F7F000
.memc_mask
  EQUD    &3C7F000

REM Soft copy of write-only paging register
.page_softcopy
  EQUB    0
  ALIGN

REM Reset loader state (i.e. expose expansion card space)
.loader_reset
  LDR     R10, fast_mask
  AND     R10, R11, R10
  ADD     R10, R10, #pagereg%
  TEQP    PC, #i_bit% OR svc_mode%
  LDRB    R3, page_softcopy
  REM Only zero out ROM page, leaving ethernet bits untouched
  AND     R3, R3, #eth_pagemask%
  STRB    R3, page_softcopy
  STRB    R3, [R10]
  BICS    PC, R14, #v_bit%

REM Read a byte from code space
.loader_read
  REM Address 0 in code space is arbitrary. We use the first
  REM byte following the end of the loader.
  ADD     R1, R1, #chunkend_loader  \ Fiddle the address
  CMP     R1, #rom_size%
  SUBGE   R1, R1, #chunkend_loader
  ADRGE   R0, loader_err_atb
  ORRGES  PC, R14, #v_bit%
  LDR     R10, fast_mask
  AND     R10, R11, R10
  ADD     R10, R10, #pagereg%
  MOV     R2, R1, ASR #rom_addrbits% \ Get page #
  TEQP    PC, #i_bit% OR svc_mode%
  LDRB    R3, page_softcopy
  AND     R3, R3, #eth_pagemask%    \ Preserve ethernet RAM page
  ORR     R2, R2, R3                \ OR in new ROM page
  STRB    R2, page_softcopy
  STRB    R2, [R10]
  SUB     R10, R10, #pagereg%
  BIC     R2, R1, #&7F << rom_addrbits% \ Mask out page bits
  LDRB    R0, [R10, R2, ASL #2]     \ Bytes at word intervals
  SUB     R1, R1, #chunkend_loader  \ Restore R1
  BICS    PC, R14, #v_bit%

REM We don't implement write, since writing to the 39SF010 is a
REM whole song-and-dance
.loader_write
  ADR     R0, loader_err_nw
  ORRS    PC, R14, #v_bit%

REM Loader SWI interface
REM R0 - Reason code
REM       0 - Set ethernet page
REM       1 - Power on ENC624J600
REM       2 - Enable interrupts
REM R1 - Argument
REM       R0=0 - Page number
REM       R0=1 - Unused
REM       R0=2 - Unused
.loader_swi
  CMP     R0, #0
  BEQ     loader_swi_ethpage
  CMP     R0, #1
  BEQ     loader_swi_poweron
  CMP     R0, #2
  BEQ     loader_swi_irqon
  ADRNE   R0, loader_err_swi
  ORRNES  PC, R14, #v_bit%
.loader_swi_ethpage
  LDR     R10, fast_mask
  AND     R10, R11, R10
  ADD     R10, R10, #pagereg%
  TEQP    PC, #i_bit% OR svc_mode%
  LDRB    R2, page_softcopy
  AND     R2, R2, #rom_pagemask%
  ORR     R2, R2, R1, ASL #rom_pagebits%
  STRB    R2, page_softcopy
  STRB    R2, [R10]
  BICS    PC, R14, #v_bit%
.loader_swi_poweron
REM Do a dummy read to an ENC624J600 register to enable power
  LDR     R10, fast_mask
  AND     R10, R11, R10
  ADD     R10, R10, #encbase%
  TEQP    PC, #i_bit% OR svc_mode%
  ADD     R10, R10, #encbase%
  LDRB    R10, [R10]
  BICS    PC, R14, #v_bit%
.loader_swi_irqon
REM Do a dummy read to MEMC space to enable IRQs
  LDR     R10, memc_mask
  AND     R10, R11, R10
  TEQP    PC, #i_bit% OR svc_mode%
  LDRB    R10, [R10]
  BICS    PC, R14, #v_bit%

.loader_err_atb
  EQUD    &500
  EQUS    "Address too big" + CHR$0
.loader_err_nw
  EQUD    &501
  EQUS    "Can't write" + CHR$0
  ALIGN
.loader_err_swi
  EQUD    &502
  EQUS    "Invalid reason code" + CHR$0
  ALIGN
]
=0


