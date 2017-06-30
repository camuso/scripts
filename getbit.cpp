#include <iostream>
#include <string>
#include <sstream>

using namespace std;

class getbit {
public:
	getbit() {};
	int run(int argc, char *argv[]);
	bool isint(string&);
	bool str2int(string&, int&);

private:
	bool hexdec;
};


// Determines if a bit is set in a mask.
// getbit bit mask

bool getbit::isint(string& s)
{
    bool isnumber = true;

   //  cout << "hexdec: " << (hexdec ? "true" : "false") << endl;

    for(string::const_iterator k = s.begin(); k != s.end(); ++k) {
        if (hexdec)
            isnumber = isnumber && isxdigit(*k);
        else
            isnumber = isnumber && isdigit(*k);
    }

    return isnumber;
}

// This code converts from string to number safely.
//
bool getbit::str2int(string& str, int& num)
{
    stringstream ss(str);

    if (!isint(str))
        return false;

    if (hexdec)
        return (ss >> hex >> num);
    else
        return (ss >> num);
}

int getbit::run(int argc, char *argv[])
{
	int mask;
	int bit;
	string str;

	if(argc < 3)
		return 0;

	this->hexdec = false;
        str = argv[1];

        if (!str2int(str, bit))
		return 0;

	this->hexdec = true;
	str = argv[2];

	if (!str2int(str, mask))
		return 0;

	bit = 1 << bit;
	// cout << (bit & mask);
	return !!(bit & mask);
}

int main(int argc, char *argv[])
{
	getbit gb;
	return gb.run(argc, argv);
}

