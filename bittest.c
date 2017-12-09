#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <inttypes.h>

#define min(x, y)   (((x) < (y)) ? (x) : (y))
typedef unsigned char u8;

#define ACPI_MASKABLE_GPE_MAX   0x80
#define BITS_PER_INT (sizeof(unsigned int) * 8)
#define GPE_MASK_ARRAY_SIZE (ACPI_MASKABLE_GPE_MAX / BITS_PER_INT)

#define BIT_INDEX(bit) (bit / BITS_PER_INT)
#define BIT_OFFSET(bit) (bit % BITS_PER_INT)

#define ACPI_GPE_MASK_SET_BIT(bit) \
	acpi_masked_gpes[BIT_INDEX(bit)] |= (1 << BIT_OFFSET(bit))

#define ACPI_GPE_MASK_CLR_BIT(bit) \
	acpi_masked_gpes[BIT_INDEX(bit)] &= ~(1 << BIT_OFFSET(bit))

#define ACPI_GPE_MASK_TEST_BIT(bit) \
	!!(acpi_masked_gpes[BIT_INDEX(bit)] & (1 << BIT_OFFSET(bit)))

static unsigned int acpi_masked_gpes[GPE_MASK_ARRAY_SIZE];
static int acpi_current_gpe_count = 128;

static int acpi_gpe_set_masked_gpes(char *val)
{
	unsigned gpe;

	gpe = strtoul(val, NULL, 0);
	if (gpe >= ACPI_MASKABLE_GPE_MAX)
		return -1;
	ACPI_GPE_MASK_SET_BIT(gpe);

	return 1;
}

void acpi_gpe_apply_masked_gpes(void)
{
	u8 gpe;

	for (gpe = 0;
	     gpe < min(ACPI_MASKABLE_GPE_MAX, acpi_current_gpe_count);
	     gpe++) {
		if (ACPI_GPE_MASK_TEST_BIT(gpe)) {
			printf("Masking GPE 0x%x.\n", gpe);
		}
	}
}


int main(int argc, char *argv[])
{
	char *cp = argv[1];
	int bit;

	sscanf(cp, "%d", &bit);

	if ((acpi_gpe_set_masked_gpes(cp) < 1)) {
		printf("%s is an invalid GPE number\n", cp);
		return 1;
	}

	printf("bit: %3d bitmap: %08x.%08x.%08x.%08x\n",
		bit,
		acpi_masked_gpes[3],
		acpi_masked_gpes[2],
		acpi_masked_gpes[1],
		acpi_masked_gpes[0]);

	acpi_gpe_apply_masked_gpes();

	return 0;
}
