#include <iostream>
#include <string>
#include <sstream>

using namespace std;

// Toggle a bit in a  bit mask

// This code converts from string to number safely.
//
bool str2int(string& str, int& num)
{
	stringstream ss(str);
	if (ss >> num)
		return true;
	else
		return false;
}

int main(int argc, char *argv[])
{
	int mask;
	int bit;
	string str;

	if(argc < 3)
		return 1;

        str = argv[1];
        if (!str2int(str, bit))
		return 3;

	str = argv[2];
        if (!str2int(str, mask))
		return 5;

	bit = 1 << bit;
	cout << (bit xor mask);

	return 0;
}

