#include <iomanip>
#include <iostream>
#include <sstream>
#include <fstream>
#include <utility>

#include <boost/program_options.hpp>

// Storage for the memory image we want to write (I think this is the right size?)
#define IMGSIZE 4096
#define IMGWIDTH 16 // Change if INSTRSIZE changes
#define INSTRSIZE unsigned short
INSTRSIZE memory[IMGSIZE];

// list of reserved words paired with value
// if value -1, then it is not an instruction and must be translated to one
// or placed directly into memory somewhere
std::vector<std::pair<std::string,INSTRSIZE> > reservedwords;

// Count the total number of instructions in reserved words
unsigned int totalinstrs;

// list of labels and calculated location
std::vector<std::pair<std::string,INSTRSIZE> > labels;
// The instructions to put into memory
std::vector<INSTRSIZE> instructions;

// Reads the file into data
void readfile(const std::string& file, std::string& data);

// Writes memory to a file
void writefile(const std::string& outfile);

// Creates all the labels
// Returns a string which replaces ',' with ' ', and removes all comments
// What else??
void firstpass(const std::string& assembly, std::stringstream& is);

// Translates into machine code
void secondpass(std::stringstream& is);

void createreservedwords();
INSTRSIZE getValue(const std::string& name);
void store(INSTRSIZE start);
void store(INSTRSIZE start, INSTRSIZE value);
void range(std::ostream& os, INSTRSIZE value, INSTRSIZE begin, INSTRSIZE end);
void hprint(std::ostream& os, INSTRSIZE value);
std::string stripcomment(std::stringstream& is, const std::string& token);

int main(int argc, char* argv[]) {

	// file is the file to read in
	// out is the file to save to
	std::string file, out;

	// Mess for reading CLI options using boost::program_options
	{
	namespace po = boost::program_options;
	po::options_description desc( "Arguments:" ); 
	desc.add_options()
		( "help", "Display this message." )
		( "file", po::value<std::string>(), "The assembly file." )
		( "out", po::value<std::string>(), "Where to save the compiled file." )
	;  

	po::variables_map vm;
	po::store( po::parse_command_line( argc, argv, desc ), vm ); 
	po::notify( vm ); 

	if( vm.count("help") ) {
		std::cout << desc << '\n';
		return 1; 
	}  

	// check for a file to read and save to
		if( vm.count("file") )
			file=vm["file"].as<std::string>();
		else {
			std::cout << "No file to read! See --help.\n";
			return 1;
		}
		if( vm.count("out") )
			out=vm["out"].as<std::string>();
		else {
			std::cout << "No file to save to! See --help.\n";
			return 1;
		}
	}

	for(int i = 0; i < IMGSIZE; ++i)
		memory[i] = 0xdead;

	createreservedwords();

	// the string to store the unparsed file into
	std::string assembly;
	readfile(file,assembly);

	std::stringstream parsed(std::stringstream::in | std::stringstream::out);
	firstpass(assembly,parsed);

	for(int i = 0; i < labels.size(); ++i) {
		std::cout << labels[i].first << ' '; 
		hprint(std::cout,labels[i].second);
		std::cout << '\n';
	}

	/*
	do {
		std::string x;
		parsed >> x;
		std::cout << x << ' ';
	} while(parsed.good());
	*/
	
	secondpass(parsed);

	writefile(out);
	return 0;
}

void readfile(const std::string& file, std::string& data) {
	using namespace std;
	ifstream ifs;
	ifs.open(file.c_str(),ios::binary);
	if(!ifs.is_open()) {
		cout << "Error: Could not open " << file << endl;
		exit(1);
	}

	// get the size of the file
	ifs.seekg(0,ios::end);
	long int length = ifs.tellg();
	ifs.seekg(0,ios::beg);

	char buf[length];

	// read the file in one go
	ifs.read(buf,length);
	ifs.close();

	// copy file to data
	data.assign(buf,length);
}

void writefile(const std::string &writefile) {
	using namespace std;
	ofstream of(writefile.c_str(), ofstream::binary);

	// Required mif headers. see http://www.altera.com/support/examples/verilog/ver_ram.html#mif
	of << "WIDTH=" << IMGWIDTH << ";\n"; 
	of << "DEPTH=" << IMGSIZE <<";\n";
	of << "ADDRESS_RADIX=HEX;\n";		// unsigned decimal
	of << "DATA_RADIX=HEX;\n";	// unsigned decimal with WIDTH bits

	of << "CONTENT BEGIN\n";

	for(INSTRSIZE i=1, j=0; i <= IMGSIZE; ++i) {
		if(memory[i]==memory[j]) {
			if(i==IMGSIZE-1) {
				range(of,memory[j],j,i);
				break;
			}
		}
		else if ( (i-j) > 1) {
			range(of,memory[j],j,i-1);
			j=i;
		}
		else {
			hprint(of,j);
			of << " : ";
			hprint(of,memory[j]);
			of << ";\n";
			++j;
		}
	}

	of << "END;\n";

	of.close();
}

void firstpass(const std::string& assembly, std::stringstream& out) {
	using namespace std;
	stringstream is(assembly, stringstream::in | stringstream::out);
	string token;
	unsigned long int index;
	unsigned int i;
	unsigned long int address = 0;

	vector<pair<string,INSTRSIZE> > datalabel;

	// Read each token
	while(is.good()) {
		is >> token;

		token = stripcomment(is,token);

		if((index = token.find(':', 0)) != -1) {	// If token is a label, parse.
			string label = token.substr(0,index);

			unsigned int size = labels.size();
			for(i = 0; i < size; ++i) 
				if(!label.compare(labels[i].first))
					break;

			if(i == size)	// If label has not been initialized before, add it to labels
				labels.push_back(pair<string,INSTRSIZE>(label,address));
			else
				cout << "Warning: label " << label <<
					" has been declared more than once. The first instance will be used.\n";
		}
		else if(!is.good())
			break;
		else if(token.at(0) == '.') {
			// .ORIG || .DATA
			if(!token.compare(".ORIG")) {
				// Put .ORIG back into parsed data
				out << ' ' <<  token << ' ';

				// Get the address
				is >> token;
				token = stripcomment(is,token);
				// Hex?
				if(!token.substr(0,2).compare("0x")) {
					token = token.substr(2,token.size()-2);
					istringstream conv(token);
					conv >> hex >> address;	
				}
				// Decimal
				else {
					istringstream conv(token);
					conv >> address;
				}
				address/=2;
				// Put decimal address into parsed data
				out << ' ' << address << ' ';
			}
			else if(!token.compare(".DATA")) { 
				INSTRSIZE value = 0;
				// Get the address
				is >> token;
				token = stripcomment(is,token);
				// Label?
				if(isalpha(token.at(0))) {
					// scan for existing labels
					bool found = false;
					for(int j = 0; j < labels.size(); ++j) {
						if(!labels[j].first.compare(token)) {
							value = labels[j].second;
							found = true;
							break;
						}
					}
					if(!found) {
						datalabel.push_back(pair<string,INSTRSIZE>(token,address));
						++address;
						continue;
					}

				}
				// Hex?
				else if(!token.substr(0,2).compare("0x")) {
					token = token.substr(2,token.size()-2);
					istringstream conv(token);
					conv >> hex >> value;	
				}
				// Decimal
				else {
					istringstream conv(token);
					conv >> value;
				}
				// Put decimal address into memory
				store(address,value);
				++address;	// Leave a space for the data
			}
			else {
				cout << "Invalid token: " << token << endl;
				exit(1);
			}
		}
		else if (token.size() > 0) {	// Token is neither label nor comment. If it's an instruction, increase the address and continue.
			// Replace other separators with white space
			unsigned int loc = 0;
			while( (loc=token.find(',',loc)) != -1)
				token.at(loc)=' ';
			loc=0;
			if( (loc=token.find('(',loc)) != -1)
				token.at(loc)=' ';
			loc=0;
			if( (loc=token.find(')',loc)) != -1)
				token.at(loc)=' ';



			for(i = 0; i < totalinstrs; ++i) {
				if(token.compare(reservedwords[i].first) == 0) { // matching instruction?
					// Pseudo instruction that just drops in a change
					if(!token.compare("B")) 
						token = " BEQ R0 R0 ";
					++address;
					break;
				}
			}
			out << ' ' <<  token << ' ';
		}
	}

	// Test label table (Can remove when done)
	//for(unsigned int i = 0; i < labels.size(); i++)
		//cout << labels[i].first << " " << labels[i].second << "\n";

	// Now fill in the missing .DATA now that we should have found all the labels
	unsigned int loc = 0;
	for(unsigned int i = 0; i < datalabel.size(); ++i) {
		for(unsigned int j = 0; j < labels.size(); ++j) {
			if(datalabel[i].first.compare(labels[j].first) == 0) {
				loc=j;
				goto found; // lololol
			}
		}
		cout << "Error: Missing label " << datalabel[i].first << endl;
		exit(1);
found:
		// store(address,value)
		store(datalabel[i].second,labels[loc].second*2);
	}
}

// This could probably divided up into multiple functions, but I'm lazy right now
// I'll do it later if things become much more complicated
void secondpass(std::stringstream& is) {
	using namespace std;

	string token;
	int instrcnt = 0;
	INSTRSIZE address = 0;
	bool reverse12, offset, ALU, B, ADDI, JMP, LW, SW, NOT, SUBI;

	// Read each token
	while(is.good()) {
		offset = reverse12 = ALU = ADDI = B = JMP = LW = SW = NOT = SUBI = false;
		is >> token;
		if(!is.good())
			break;
		cout << "I: " << token << '\t';
		
		if (token.at(0) == '.') {
			if(!token.compare(".ORIG")) {
				if(instructions.size()>0)
					store(address);
				is >> address;
				instrcnt=address;
			}
			cout << address << '\n';
		}
		else {
			// We use this to help detect invalid code
			unsigned long int oldcount = instrcnt;

			// Find instruction and handle it
			for(unsigned int i = 0; i < totalinstrs; ++i) {
				if(token.compare(reservedwords[i].first) == 0) { // matching instruction?
					++instrcnt;

					string instruction = reservedwords[i].first;
					INSTRSIZE instr = reservedwords[i].second;
					if(instr == 0xffff) { // We found a psuedo-instruction or something else
						if(!token.compare("GT")) {
							reverse12 = true;
							instr = getValue("LT");
						}
						else if(!token.compare("GE")) {
							reverse12 = true;
							instr = getValue("LE");
						}
						else if(!token.compare("SUBI")) {
							SUBI=true;
							instr = getValue("ADDI");
						}
						else if(!token.compare("NOT")) {
							NOT=true;
							instr = getValue("NOR");
						}
					}
					
					if ( (instr>>13) == 0 )
						ALU = true;
					else if ( (instr>>13) == 1 )
						ADDI = true;
					else if ( (instr>>13) == 5  || (instr>>13) == 4 )
						reverse12 = true;
					else if ( (instr>>14) == 1 || (instr>>13) == 3 ) {
						B = true;
						offset = true;
					}
					else if( (instr>>14) ==3) {
						offset=true;
						JMP=true;
					}

					if( (instr>>13) == 4)
						LW=true;
					else if( (instr>>13) == 5)
						SW=true;

					//---- The first argument to an instruction is always a register
					if(is.good()) {
						is >> token;
						token = stripcomment(is,token);
					}
					else
						cout << "Error: Incomplete file?" << endl;

					cout << token << '\t';


					for(unsigned int j = 0; j < reservedwords.size(); ++j) {
						if(token.compare(reservedwords[j].first) == 0) {
							if(ALU || JMP)
								instr = instr | (reservedwords[j].second << 4);
							else if(B)
								instr = instr | (reservedwords[j].second << 10);
							else
								instr = instr | (reservedwords[j].second << 7);
							break;
						}
					}

					//---- The second argument to an instruction is {register|offset|label offset}
					//---- The offsets are due to the way the first pass does things
					if(is.good()) {
						is >> token;
						token = stripcomment(is,token);
					}
					else
						cout << "Error: Incomplete file?" << endl;

					cout << token << '\t';

					// Is it an offset?
					if(isdigit(token.at(0)) || token.at(0)=='-') {
						istringstream conv(token);
						INSTRSIZE imm;

						// Hex -> decimal for immediates
						if(!token.substr(0,2).compare("0x")) {
							token = token.substr(2,token.size()-2);
							istringstream conv(token);
							conv >> hex >> imm;	
						}
						else
							conv >> imm;

						imm &= 0x7F;
						if( !(imm >= 0x80 && imm <= 0xFF) && !(imm >= 0 && imm <= 0x7F) ) {
							cout << "Offset too large or small: " << imm << endl;
							exit(1);
						}
						instr |= imm;
					}
					else if(LW || SW) {
						cout << hex;
						for(int j=0; j < labels.size(); ++j) {
							if(!labels[j].first.compare(token)) {
								instr |= (labels[j].second*2) & 0x7F;
								break;
							}
						}

					}
					else {
						for(unsigned int j = 0; j < reservedwords.size(); ++j) {
							if(token.compare(reservedwords[j].first) == 0) {
								if(ALU || JMP)
									instr = instr | (reservedwords[j].second << 10);
								else if(reverse12 || B)
									instr = instr | (reservedwords[j].second << 7);
								else
									instr = instr | (reservedwords[j].second << 10);
								// Copy SRC1 -> SRC2 for pseudo instruction
								if(NOT) 
									instr = instr | (reservedwords[j].second << 7);
								break;
							}
						}
					}

					if(!JMP && !NOT) {
						
						// Next comes a register?
						if(is.good()) {
							is >> token;
							token = stripcomment(is,token);
						}
						else 
							cout << "Error: Incomplete file?" << endl;

						cout << token << '\t';

						if(isdigit(token.at(0)) || token.at(0)=='-') {
							istringstream conv(token);
							INSTRSIZE imm;

							// Hex -> decimal for immediates
							if(!token.substr(0,2).compare("0x")) {
								token = token.substr(2,token.size()-2);
								istringstream conv(token);
								conv >> hex >> imm;	
							}
							else
								conv >> imm;

							imm &= 0x7F;
							if( !(imm >= 0x80 && imm <= 0xFF) && !(imm >= 0 && imm <= 0x7F) ) {
								cout << "Immediate too large or small: " << imm << endl;
								exit(1);
							}
							if(SUBI)
								imm=(-imm)&0x7F;

							instr |= imm;
						}
						else if(B||ADDI) {
							for(int j=0; j < labels.size(); ++j) {
								if(!labels[j].first.compare(token)) {
									instr |= (labels[j].second-instrcnt) & 0x7F;
									break;
								}
							}

						}
						else {

							for(unsigned int j = 0; j < reservedwords.size(); ++j) {
								if(token.compare(reservedwords[j].first) == 0) {
									if(ALU)
										instr = instr | (reservedwords[j].second << 7);
									else if(reverse12)
										instr = instr | (reservedwords[j].second << 10);
									else
										instr = instr | (reservedwords[j].second << 4);
									break;
								}
							}
						}
					}


					cout << '\t';
					hprint(cout,instrcnt-1);
					cout << " : ";
					hprint(cout,instr);
					cout << '\n';
					instructions.push_back(instr);


				}
			}
			// Incorrect code! (or a bug above)
			if(oldcount == instrcnt) {
				cout << "\nError: " << token << " is not an instruction!" << endl;
				exit(1);
			}
		}
	}
	store(address);
}

void createreservedwords() {
	using namespace std;
	// save some typing
	vector<pair<string,INSTRSIZE> > &rw = reservedwords;

	rw.push_back(pair<string,INSTRSIZE>(".ORG",-1));
	rw.push_back(pair<string,INSTRSIZE>(".DATA",-1));

	// Convert all these to base 16 or base 8?

//--- INSTRUCTIONS ---//
	// ALU things
	// No shifting needed since primary op is 000
	rw.push_back(pair<string,INSTRSIZE>("ADD",0));
	rw.push_back(pair<string,INSTRSIZE>("SUB",1));
	rw.push_back(pair<string,INSTRSIZE>("LT",4));
	rw.push_back(pair<string,INSTRSIZE>("LE",5));
	rw.push_back(pair<string,INSTRSIZE>("AND",8));
	rw.push_back(pair<string,INSTRSIZE>("OR",9));
	rw.push_back(pair<string,INSTRSIZE>("XOR",10));
	rw.push_back(pair<string,INSTRSIZE>("NAND",12));
	rw.push_back(pair<string,INSTRSIZE>("NOR",13));
	rw.push_back(pair<string,INSTRSIZE>("NXOR",14));

	rw.push_back(pair<string,INSTRSIZE>("ADDI",1<<13));
	rw.push_back(pair<string,INSTRSIZE>("SUBI",-1));
	rw.push_back(pair<string,INSTRSIZE>("NOT",-1));
	rw.push_back(pair<string,INSTRSIZE>("GT",-1));
	rw.push_back(pair<string,INSTRSIZE>("GE",-1));

	// memory things
	rw.push_back(pair<string,INSTRSIZE>("LW",1<<15));
	rw.push_back(pair<string,INSTRSIZE>("SW",5<<13));

	// branchy things
	rw.push_back(pair<string,INSTRSIZE>("BEQ",1<<14));
	rw.push_back(pair<string,INSTRSIZE>("BNE",3<<13));
	rw.push_back(pair<string,INSTRSIZE>("JMP",3<<14));
	rw.push_back(pair<string,INSTRSIZE>("JRL",rw.back().second)); // secondary op is 0
	rw.push_back(pair<string,INSTRSIZE>("B",-1));

	//rw.push_back(pair<string,INSTRSIZE>("",7<<13)); // RESERVED

	totalinstrs = rw.size();
//--- REGISTERS ---//
	// These are not shifted since we have to shift them
	// based on order and position of instr arguments
	// Assumed that they were just numbered 0-7
	// Use rw.back().second to create aliases
	rw.push_back(pair<string,INSTRSIZE>("R0",0));
	rw.push_back(pair<string,INSTRSIZE>("A0",rw.back().second));

	rw.push_back(pair<string,INSTRSIZE>("R1",1));
	rw.push_back(pair<string,INSTRSIZE>("A1",rw.back().second));

	rw.push_back(pair<string,INSTRSIZE>("R2",2));
	rw.push_back(pair<string,INSTRSIZE>("A2",rw.back().second));

	rw.push_back(pair<string,INSTRSIZE>("R3",3));
	rw.push_back(pair<string,INSTRSIZE>("A3",rw.back().second));
	rw.push_back(pair<string,INSTRSIZE>("RV",rw.back().second));

	rw.push_back(pair<string,INSTRSIZE>("R4",4));
	rw.push_back(pair<string,INSTRSIZE>("RA",rw.back().second));

	rw.push_back(pair<string,INSTRSIZE>("R5",5));
	rw.push_back(pair<string,INSTRSIZE>("GP",rw.back().second));

	// This is for system use, so if we get a hit should we error?
	rw.push_back(pair<string,INSTRSIZE>("R6",6));

	rw.push_back(pair<string,INSTRSIZE>("R7",7));
	rw.push_back(pair<string,INSTRSIZE>("SP",rw.back().second));

}

INSTRSIZE getValue(const std::string& name) {
	for(unsigned int i = 0; i < reservedwords.size(); ++i)
		if( reservedwords[i].first.compare(name) == 0)
			return reservedwords[i].second;
	return -1;
}

void store(INSTRSIZE start) {
	for(unsigned int i = 0; i < instructions.size(); ++i, ++start) {
		memory[start] = instructions[i];
	}
	instructions.clear();
}

void store(INSTRSIZE start, INSTRSIZE value) {
	memory[start] = value;
}

void range(std::ostream& os, INSTRSIZE value, INSTRSIZE begin, INSTRSIZE end) {
	os << '['; 
	hprint(os,begin);
	os << "..";
	hprint(os,end);
	os << "] : ";
	hprint(os,value);
	os << ";\n";

}

void hprint(std::ostream& os, INSTRSIZE value) {
	os << std::hex;
	os << ((value & 0xf000) >> 12) <<
		((value & 0x0f00) >> 8) <<
		((value & 0x00f0) >> 4) <<
		(value & 0x000f); 

	os << std::dec;
}

std::string stripcomment(std::stringstream& is, const std::string& token) {
	using namespace std;

	string toss;
	size_t loc;
	if((loc=token.find(';', 0)) != string::npos) {	// If token has a comment, move to next line
		if(is.good())
			getline(is, toss);
		if(loc != 0) {
			toss=token.substr(0,loc);
			return toss;
		}
	}

	if(token.size()==1 && token.at(0) == ';')
		return " ";
	return token;
}
