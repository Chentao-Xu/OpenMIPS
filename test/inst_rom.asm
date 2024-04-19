
inst_rom.om：     文件格式 elf32-tradbigmips


Disassembly of section .text:

00000000 <_start>:
   0:	34011234 	li	at,0x1234
   4:	ac010000 	sw	at,0(zero)
   8:	34021234 	li	v0,0x1234
   c:	34010000 	li	at,0x0
  10:	8c010000 	lw	at,0(zero)
  14:	10220003 	beq	at,v0,24 <Label>
  18:	00000000 	nop
  1c:	34014567 	li	at,0x4567
  20:	00000000 	nop

00000024 <Label>:
  24:	340189ab 	li	at,0x89ab
  28:	00000000 	nop

0000002c <_loop>:
  2c:	0800000b 	j	2c <_loop>
  30:	00000000 	nop
	...

Disassembly of section .reginfo:

00000040 <.reginfo>:
  40:	00000006 	srlv	zero,zero,zero
	...

Disassembly of section .MIPS.abiflags:

00000058 <_ram_end-0x18>:
  58:	00002001 	movf	a0,zero,$fcc0
  5c:	01010001 	movt	zero,t0,$fcc0
	...
  68:	00000001 	movf	zero,zero,$fcc0
  6c:	00000000 	nop

Disassembly of section .gnu.attributes:

00000000 <.gnu.attributes>:
   0:	41000000 	0x41000000
   4:	0f676e75 	jal	d9db9d4 <_ram_end+0xd9db964>
   8:	00010000 	sll	zero,at,0x0
   c:	00070401 	0x70401
