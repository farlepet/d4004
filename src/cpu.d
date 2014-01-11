module cpu;

import std.stdio;

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
 *      - C - Carry
 */

 enum
 {
 	COND_INV  = 1, // Invert condition
 	COND_ACCZ = 2, // Accumulator == 0
 	COND_CALO = 4, // Carry or Link == 1
 	COND_TEST = 8  // Test pin == 0
 }

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

	ubyte[4096] rom; // 4K of 8-bit words

	ubyte[640] ram; // 5120 bits of ram

	ubyte test; // Test pin

	this()
	{
		for(int i = 0; i < 16; i++) r[i] = 0;
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

	int next_instr()
	{
		ubyte instr = rom[pc++];

		switch(instr & 0xF0)
		{
			case 0x00: // NOP
				break;

			case 0x10: // JCN -- conditional jump
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
					this.pc &= ~0xFFFF;
					this.pc |= addr;
				}
				break;

			case 0x20: // FIM -- fetch immediate
				ubyte instr2 = rom[pc++]; // 2-byte instruction
				ubyte reg = instr & 0x0E;
				ubyte addr = instr2;
				ubyte data = rom[(pc & ~0xFFFF) | addr];
				r[reg]   = data >> 4 & 0x0F;
				r[reg+1] = data & 0x0F;
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
					pc &= ~0xFFFF;
					pc |= cast(ubyte)(r[reg] << 4 | r[reg + 1]);
				}
				break;

			case 0x40: // JUN -- jump unconditional
				ubyte instr2 = rom[pc++]; // 2-byte instruction
				ushort addr = ((instr << 8) | instr2);
				pc = addr;
				break;

			case 0x50: // JMS -- jump to subroutine
				ubyte instr2 = rom[pc++]; // 2-byte instruction
				ushort addr = ((instr << 8) | instr2);
				add_call_stack(addr);
				break;

			default:
				// Error handle?
				break;
		}

		return 0;
	}
}