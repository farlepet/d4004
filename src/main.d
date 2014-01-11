/* Intel 4004 emulator
 *
 * NOTE: THIS IS NOT A FAITHFUL EMULATOR, IT DOES NOT SEPREATELY EMULATE
 *   THE CPU, MEMORY ACCESS DEVICES, MEMORY, AND IO DEVICES!
 */

import std.stdio;

import cpu;


cpu_4004 cpu4004();

int main(char[][] argc)
{
	writefln("d4004 -- An Intel 4004 emulator written in D");

	return 0;
}