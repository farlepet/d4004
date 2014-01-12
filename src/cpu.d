module cpu;

import std.c.stdlib;
import std.stdio;
import std.file;

/* Register information:
 *
 * A         - 4-bit Accumulator
 * R0 - R15  - 4-bit General-purpose registers
 * PC        - 12-bit Program Counter
 * PC1 - PC3 - 12-bit Call stack registers
 * status    - 4-bit flags register
 *   - CPZS
 *      - S - Sign
 *      - Z - Zero
 *      - P - Parity
 *      - C - Carry (and/or link?)
 */

enum
{
	COND_INV  = 1, // Invert condition
	COND_ACCZ = 2, // Accumulator == 0
	COND_CALO = 4, // Carry or Link == 1
	COND_TEST = 8  // Test pin == 0
}

enum
{
	STAT_SIGN   = 1, // Sign
	STAT_ZERO   = 2, // Zero
	STAT_PARITY = 4, // Parity
	STAT_CARRY  = 8  // Carry
}

static ubyte[16] do_kbp = [ 0, 1, 2, 15, 3, 15, 15, 15, 4, 15, 15, 15, 15, 15, 15, 15 ];

class cpu_4004
{
	ubyte a; // 4 bit accumulator

	ubyte[16] r; // General-Purpose registers, all 4 bits

	ushort pc; // 12 bits

	// Call stack, all 12 bits
	ushort pc1;
	ushort pc2;
	ushort pc3;

	ubyte status; // 4 bits

	ubyte[4096] rom; // 16 ROM chips, 256 bytes each

	ubyte[1280] ram; // 640 bytes

	// Hardware:
	ubyte test; // Test pin

	// 4-bits
	ubyte ram_addr = 0;
	ubyte rom_addr = 0;

	ubyte ram_cmdline = 0; // Which ram bank to use (3 bits)



	this()
	{
		r[0..15] = 0;
		pc     = 0;
		pc1    = 0;
		pc2    = 0;
		pc3    = 0;
		status = 0;
	}

	private void add_call_stack(ushort new_pc)
	{
		pc3 = pc2;
		pc2 = pc1;
		pc1 = pc;
		pc  = new_pc;
	}

	private void sub_call_stack()
	{
		pc  = pc1;
		pc1 = pc2;
		pc2 = pc3;
		pc3 = 0;
	}

	int next_instr()
	{
		int instr_cyc = 1; // 1 for reading the opcode (1 byte)

		ubyte instr = rom[pc++];

		writefln("Executing instruction: %02X", instr);

		switch(instr & 0xF0)
		{
			case 0x00: // NOP
				break;

			case 0x10: // JCN -- conditional jump
				instr_cyc++; // 2-byte == 2 cycles
				ubyte instr2 = rom[pc++]; // 2-byte instruction
				ubyte cond = instr & 0x0F; // Condition
				ubyte addr = instr2; // Address
				int jump = ((((cond & COND_ACCZ) == COND_ACCZ) && (this.a == 0)) ||
							(((cond & COND_CALO) == COND_CALO) && (/*Don't know what this is yet!*/0)) ||
							(((cond & COND_TEST) == COND_TEST) && (this.test == 0)));
				if(cond & COND_INV) jump = !jump;
				if(jump)
				{
					// We are jumping within the same ROM
					this.pc &= ~0xFF;
					this.pc |= addr;
				}
				break;

			case 0x20:
				if(!(instr & 1)) // FIM -- fetch immediate
				{
					instr_cyc++; // 2-byte == 2 cycles
					ubyte instr2 = rom[pc++]; // 2-byte instruction
					ubyte reg = instr & 0x0E;
					ubyte addr = instr2;
					ubyte data = rom[(pc & ~0xFF) | addr];
					r[reg]   = data >> 4 & 0x0F;
					r[reg+1] = data & 0x0F;
				}
				else // SRC -- send register control
				{
					ubyte reg = instr & 0x0E;
					ram_addr = cast(ubyte)(r[reg] << 4 | r[reg+1]);
					rom_addr = cast(ubyte)(r[reg] << 4 | r[reg+1]);
				}
				break;

			case 0x30:
				if(!(instr & 1)) // FIN -- fetch indirect
				{
					ubyte addr = cast(ubyte)(r[0] << 4 | r[1]);
					ubyte data = rom[addr];
					ubyte reg = instr & 0x0E;
					r[reg]   = data >> 4 & 0x0F;
					r[reg+1] = data & 0x0F;
				}
				else // JIN -- jump indirect
				{
					ubyte reg = instr & 0x0E;
					pc &= ~0xFF;
					pc |= cast(ubyte)(r[reg] << 4 | r[reg + 1]);
				}
				break;

			case 0x40: // JUN -- jump unconditional
				instr_cyc++; // 2-byte == 2 cycles
				ubyte instr2 = rom[pc++]; // 2-byte instruction
				ushort addr = (((instr & 0x0F) << 8) | instr2);
				pc = addr;
				break;

			case 0x50: // JMS -- jump to subroutine
				instr_cyc++; // 2-byte == 2 cycles
				ubyte instr2 = rom[pc++]; // 2-byte instruction
				ushort addr = (((instr & 0x0F) << 8) | instr2);
				add_call_stack(addr);
				break;

			case 0x60: // INC -- increment register
				ubyte reg = instr & 0x0F;
				r[reg] = (r[reg] + 1) & 0x0F;
				break;

			case 0x70: // ISZ -- increment register, and jump if non-zero
				instr_cyc++; // 2-byte == 2 cycles
				ubyte instr2 = rom[pc++]; // 2-byte instruction
				ubyte reg = instr & 0x0F;
				r[reg] = (r[reg] + 1) & 0x0F;
				if(r[reg])
				{
					ubyte addr = instr2;
					pc &= ~0xFF;
					pc |= addr;
				}
				break;

			case 0x80: // ADD -- add register to accumulator
				ubyte reg = instr & 0x0F;
				a += r[reg] + ((status & STAT_CARRY) == STAT_CARRY);
				if(a & 0xF0)
				{
					a &= 0x0F;
					status |= STAT_CARRY;
				}
				else status &= ~STAT_CARRY;
				break;

			case 0x90: // SUB -- subtract register from accumulator
				ubyte reg = instr & 0x0F;
				ubyte oa = a;
				a += (~r[reg]) & 0x0F + ((status & STAT_CARRY) == STAT_CARRY);
				a &= 0x0F;
				if(oa < (r[reg] & 0x0F)) status &= ~STAT_CARRY;
				else status |= STAT_CARRY;
				break;

			case 0xA0: // LD -- load register into accumulator
				ubyte reg = instr & 0x0F;
				a = r[reg];
				break;

			case 0xB0: // XCH -- exchange register and accumulator
				ubyte reg = instr & 0x0F;
				ubyte temp = r[reg];
				r[reg] = a;
				a = temp;
				break;

			case 0xC0: // BBL -- branch back 1 level
				ubyte data = instr & 0x0F;
				sub_call_stack();
				a = data;
				break;

			case 0xD0: // LDM -- load data into accumulator
				ubyte data = instr & 0x0F;
				a = data;
				break;

			case 0xE0: // Ram instructions
				break;

			case 0xF0:
				switch(instr)
				{
					case 0xF0: // CLB: Clear accumulator and carry
						a = 0;
						status &= ~STAT_CARRY;
						break;

					case 0xF1: // CLC: Clear carry
						status &= ~STAT_CARRY;
						break;

					case 0xF2: // IAC: Increment accumulator
						a++;
						if(a & 0xF0) status |= STAT_CARRY;
						else status &= ~STAT_CARRY;
						a &= 0x0F;
						break;

					case 0xF3: // CMC: Complement carry
						if(status & STAT_CARRY) status &= ~STAT_CARRY;
						else status |= STAT_CARRY;
						break;

					case 0xF4: // CMA: Complement accumulator
						a = (~a) & 0x0F;
						break;

					case 0xF5: // RAL: Rotate accumulator and carry left
						int c = status & STAT_CARRY;
						int a3 = a & 0x08;
						a <<= 1;
						a &= 0x0F;
						if(a3) status |= STAT_CARRY;
						else status &= ~STAT_CARRY;
						if(c)a |= 1;
						else a &= ~1;
						break;

					case 0xF6: // RAR: Rotate accumulator and carry right
						int c = status & STAT_CARRY;
						int a0 = a & 0x01;
						a >>= 1;
						a &= 0x0F;
						if(a0) status |= STAT_CARRY;
						else status &= ~STAT_CARRY;
						if(c)a |= 8;
						else a &= ~8;
						break;

					case 0xF7: // TCC: Transmit carry to accumulator and clear carry
						a = status & STAT_CARRY;
						status &= ~STAT_CARRY;
						break;

					case 0xF8: // DAC: Decrement accumulator
						if(a == 0) status &= ~STAT_CARRY;
						else status |= STAT_CARRY;
						a = (a - 1) & 0x0F;
						break;

					case 0xF9: // TCS: Transfer carry subtract and clear carry
						if(status & STAT_CARRY) a = 10;
						else a = 9;
						status &= ~STAT_CARRY;
						break;

					case 0xFA: // STC: Set carry
						status |= STAT_CARRY;
						break;

					case 0xFB: // DAA: Decimal adjust accumulator
						if(status & STAT_CARRY || a > 9) a += 6;
						if(a & 0xF0) status |= STAT_CARRY;
						a &= 0x0F;
						break;

					case 0xFC: // KBP: Keyboard process
						a = do_kbp[a];
						break;

					case 0xFD: // DCL: Designate command line
						ram_cmdline = a & 0x07;
						break;


					case 0xFF: // Emulator-only opcode!
						return -1;

					default:
						// Error handle here?
						break;
				}
				break;

			default:
				// Error handle?
				break;
		}

		return instr_cyc;
	}
}