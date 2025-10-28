REM Utility for programming SST39SF010 podule ROMs

REM Offset of paging register relative to slot base
pagereg%=&2000

REM ARM status bits
v_bit%=1<<28

rundir$=FNrundir("@")
defname$=rundir$+".ENCRom"

PROCassemble

PRINT "EtherENC Programmer Tool"
PRINT "WARNING: Using this tool will disrupt network interfaces"
PRINT "Press ESCAPE at any time to exit":PRINT

PRINT "Installed Podules:":OSCLI "Podules":PRINT
INPUT "Slot number",slot%
SYS "Podule_HardwareAddress",,,,slot% TO ,,,slotbase%
slotbase% = slotbase% AND &3F7C000

SYS "XOS_Module", 18, "EtherENC" TO result%
IF result% = 18 THEN
  PRINT "EtherENC driver must be killed to proceed."
  PRINT "Press ESCAPE to cancel, any other key to continue"
  A$=GET$
  SYS "OS_Module", 4, "EtherENC"
ENDIF

id% = FNid
IF id% = &FFFF THEN ERROR 1,"Flash device not found"
PRINT "ROM ID bytes: ";~id%

PRINT "Filename (leave blank to use "; defname$;")";
INPUT name$

DIM buf% 131072
IF name$="" THEN name$=defname$
SYS "OS_File",255,name$,buf%,0 TO ,,,,size%

PRINT "Erasing... ";
PROCerase
PRINT "done"

PRINT "Writing... ";
PROCprogram(buf%, size%, 0)
PRINT "wrote "; size%; " bytes"

PRINT "Verifying... ";
ret%=FNverify(buf%, size%, 0)
IF ret%<0 THEN ERROR 1, "Miscompare at address " + STR$~(ret% AND &7FFFFFFF)
PRINT "OK"
END

DEF FNverify(buf%,len%,addr%)
A%=buf%
B%=len%
C%=addr%
D%=slotbase%
=USR(verify)

DEF PROCprogram(buf%,len%,addr%)
A%=buf%
B%=len%
C%=addr%
D%=slotbase%
CALL(program)
ENDPROC

DEF PROCerase
C%=slotbase%
x=USR(erase)
ENDPROC

DEF FNid
C%=slotbase%
=USR(id)

REM Ugly hack to get the directory we're running from so that we
REM can construct paths relative to it.
REM Why does BBC BASIC make this so hard???!?!?!
REM DIMs memory, so should only be called once.
REM dir$=Default directory if run directory not known (@ for CWD)
REM Returns dirname of BASIC file being executed
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


DEF PROCassemble
codesize%=512
DIM code% codesize%
FOR pass% = 8 TO 10 STEP 2
P%=code%
L%=code% + codesize%
[OPT pass%
REM Read ROM ID
REM R3=Slot base
REM Returns ID bytes in low halfword of R0
.id
  STMFD R13!,{R5,R14}
  SWI "OS_EnterOS"
  SWI "OS_IntOff"
  MOV R0,#&90
  BL command                  \ Command &90, enter ID mode
  MOV R1,#0
  BL read_                    \ Read ID byte 0
  MOV R5, R0, ASL #8
  MOV R1,#1
  BL read_                    \ Read ID byte 1
  ORR R5, R5, R0
  MOV R0,#&F0
  BL command                  \ Command &F0, exit ID mode
  MOV R0,R5
  SWI "OS_IntOn"
  TEQP PC,#0
  MOV R0,R0
  LDMFD R13!,{R5,PC}


REM Erase entire ROM
REM R3=slot base
.erase
  STMFD R13!,{R5,R14}
  SWI "OS_EnterOS"
  SWI "OS_IntOff"
  MOV R0,#&80                 \ Command &80, arm for erase
  BL command
  MOV R0,#&10                 \ Command &10, erase chip
  BL command
.erase_loop
  MOV R1,#0
  BL read_
  MOV R5, R0
  MOV R1, #0
  BL read_                    \ Read data twice
  CMP R5, R0                  \ Wait for data to stop toggling
  BNE erase_loop
  SWI "OS_IntOn"
  TEQP PC,#0
  MOV R0,R0
  LDMFD R13!,{R5,PC}


REM Verify ROM contents against a buffer
REM R0=Buffer
REM R1=Length in bytes
REM R2=Start address in ROM
REM R3=Slot base
REM Returns with R0>=0 if OK
REM Returns R0=miscompare location OR &80000000 if failed
.verify
  STMFD R13!,{R5-R8,R14}
  SWI "OS_EnterOS"
  MOV R5,R0                   \ R5 = buffer
  MOV R6,R1                   \ R6 = length
  MOV R7,R2                   \ R7 = start addr
  MOV R8,#0
  MOV R2,R3
.verify_loop
  ADD R1, R7, R8
  SWI "OS_IntOff"
  BL read_
  SWI "OS_IntOn"
  LDRB R1, [R5, R8]
  CMP R1,R0
  ADDNE R0, R7, R8
  ORRNE R0, R0, #&80000000
  BNE verify_done
  ADD R8, R8, #1
  CMP R6, R8
  BNE verify_loop
  MOV R0,R8
.verify_done
  TEQP PC,#0
  MOV R0,R0
  LDMFD R13!,{R5-R8,PC}


REM Program ROM fom a buffer
REM R0=Buffer
REM R1=Length in bytes
REM R2=Start address in ROM
REM R3=Slot base
.program
  STMFD R13!,{R5-R8,R14}
  SWI "OS_EnterOS"
  MOV R5,R0
  MOV R6,R1
  MOV R7,R2
  MOV R8,#0
  MOV R2,R3
.program_loop
  LDRB R0, [R5, R8]
  ADD R1, R7, R8
  BL programbyte
  ADD R8, R8, #1
  CMP R6, R8
  BNE program_loop
  TEQP PC,#0
  MOV R0,R0
  LDMFD R13!,{R5-R8,PC}


REM Program a single byte
REM For internal use only, must be called from SVC mode
REM R0=Byte to program
REM R1=ROM address to program
.programbyte
  STMFD R13!,{R5,R6,R14}
  SWI "OS_IntOff"
  MOV R5,R0
  MOV R6,R1
  MOV R0,#&A0
  BL command
  MOV R0,R5
  MOV R1,R6
  BL write_
.write_loop
  MOV R1,R6
  BL read_
  MOV R5,R0
  MOV R1,R6
  BL read_
  CMP R5,R0
  BNE write_loop
  SWI "OS_IntOn"
  LDMFD R13!,{R5,R6,PC}


REM Send a command to the ROM
REM For internal use only, must be called from SVC mode
REM R0=Command byte
REM R2=Slot base
.command
  STMFD R13!,{R5, R14}
  MOV R5, R0
  MOV R0, #&AA
  LDR R1, a_5555
  BL write_                   \ Write &AA to &5555
  MOV R0, #&55
  LDR R1, a_2aaa
  BL write_                   \ Write &55 to &2AAA
  MOV R0, R5
  LDR R1, a_5555
  BL write_                   \ Write command byte to &5555
  LDMFD R13!,{R5, PC}

.a_5555
  EQUD &5555
.a_2aaa
  EQUD &2AAA


REM Write a single byte to ROM
REM Internal only, must be called from SVC mode
REM R0=Data
REM R1=ROM address
REM R2=Slot base
.write_
  MOV R3, R1, ASR #11         \ R3 = page
  BIC R1, R1, #&7F << 11      \ Clear page bits from R1 addr
  ADD R2, R2, #pagereg%
  STRB R3, [R2]               \ Set page
  SUB R2, R2, #pagereg%
  STRB R0, [R2, R1, ASL #2]   \ Bytes at word addresses
  MOV PC, R14


REM Read a single byte from ROM
REM Internal only, must be called from SVC mode
REM R1=ROM address
REM R2=Slot base
REM Returns data in low byte of R0
.read_
  MOV R3, R1, ASR #11         \ R3 = page
  BIC R1, R1, #&7F << 11      \ Clear page bits from R1 addr
  ADD R2, R2, #pagereg%
  STRB R3, [R2]               \ Set page
  SUB R2, R2, #pagereg%
  LDRB R0, [R2, R1, ASL #2]   \ Bytes at word addresses
  MOV PC, R14
]
NEXT
ENDPROC


