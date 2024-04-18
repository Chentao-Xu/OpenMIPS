
inst_rom.om：     文件格式 elf32-tradbigmips


Disassembly of section .text:

00000000 <_start>:
   0:	34080001 	li	t0,0x1
   4:	34090001 	li	t1,0x1
   8:	34110004 	li	s1,0x4
   c:	340c0100 	li	t4,0x100
  10:	3c048040 	lui	a0,0x8040
  14:	008c6821 	addu	t5,a0,t4

00000018 <loop>:
  18:	01095021 	addu	t2,t0,t1
  1c:	35280000 	ori	t0,t1,0x0
  20:	35490000 	ori	t1,t2,0x0
  24:	ac890000 	sw	t1,0(a0)
  28:	8c8b0000 	lw	t3,0(a0)
  2c:	152b0004 	bne	t1,t3,40 <end>
  30:	34000000 	li	zero,0x0
  34:	00912021 	addu	a0,a0,s1
  38:	148dfff7 	bne	a0,t5,18 <loop>
  3c:	34000000 	li	zero,0x0

00000040 <end>:
  40:	1620ffff 	bnez	s1,40 <end>
  44:	34000000 	li	zero,0x0
	...

Disassembly of section .reginfo:

00000050 <.reginfo>:
  50:	00023f10 	0x23f10
	...

Disassembly of section .MIPS.abiflags:

00000068 <_ram_end-0x18>:
  68:	00002001 	movf	a0,zero,$fcc0
  6c:	01010001 	movt	zero,t0,$fcc0
	...
  78:	00000001 	movf	zero,zero,$fcc0
  7c:	00000000 	nop

Disassembly of section .gnu.attributes:

00000000 <.gnu.attributes>:
   0:	41000000 	0x41000000
   4:	0f676e75 	jal	d9db9d4 <_ram_end+0xd9db954>
   8:	00010000 	sll	zero,at,0x0
   c:	00070401 	0x70401
