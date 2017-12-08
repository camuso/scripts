#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <inttypes.h>

typedef unsigned char u8;

#define ACPI_MASKABLE_GPE_MAX   0x80
#define BITS_PER_INT (sizeof(int) * 8)
#define GPE_MASK_ARRAY_SIZE (ACPI_MASKABLE_GPE_MAX / BITS_PER_INT)

#define BIT_INDEX(bit) (bit / BITS_PER_INT)
#define BIT_OFFSET(bit) (bit % BITS_PER_INT)

static unsigned int acpi_masked_gpes[GPE_MASK_ARRAY_SIZE];

#define acpi_gpe_mask_set_bit(bit) \
        acpi_masked_gpes[BIT_INDEX(bit)] |= (1 << BIT_OFFSET(bit))

#define acpi_gpe_mask_test_bit(bit) \
        !!(acpi_masked_gpes[BIT_INDEX(bit)] & (1 << BIT_OFFSET(bit)))

static int acpi_gpe_set_masked_gpes(char *val)
{
	unsigned long gpe = strtoul(val, NULL, 0);

	acpi_gpe_mask_set_bit(gpe);

	return 1;
}

int main(int argc, char *argv[])
{
	char *cp = argv[1];
	int bit;

	sscanf(cp, "%d", &bit);

	acpi_gpe_set_masked_gpes(cp);
	printf("bit: %3d bitmap: %08x.%08x.%08x.%08x\n",
		bit,
		acpi_masked_gpes[3],
		acpi_masked_gpes[2],
		acpi_masked_gpes[1],
		acpi_masked_gpes[0]);

	acpi_gpe_mask_test_bit(bit);
	return 0;
}
