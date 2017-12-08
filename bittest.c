#include <stdio.h>
#include <inttypes.h>

#define sizeofint (sizeof(int))
#define sizeofarray 4
#define nbits (sizeofint * sizeofarray)
#define bits_per_byte 8
#define bits_per_int (sizeofint * bits_per_byte)

static unsigned int intarray[sizeofarray];

void setbit(int bit)
{
	int i;
	int k = bit;

	for (i = 0; i < sizeofarray; ++i) {
		k -= bits_per_int;
		printf("bits_per_int: %d k: %d\n", bits_per_int, k);
		if (k < 0) break;
	}

	printf ("i: %d\n", i);
	bit -= i * bits_per_int;
	printf ("bit: %d mask: %08x\n", bit, ((unsigned)1<<bit));
	intarray[i] |= ((unsigned)1<<bit);
}

void main(int argc, char **argv)
{
	int i;
	int bit;

	sscanf(argv[1], "%d", &bit);
	setbit(bit);

	for (i = 0; i < sizeofarray; ++i) {
		printf("array[%d]: %08x\n", i, intarray[i]);
	}
}
