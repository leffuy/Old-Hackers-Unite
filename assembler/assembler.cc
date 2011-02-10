#include <iostream>
#include <sstream>
#include <fstream>
#include <utility>

#include <boost/program_options.hpp>

// Storage for the memory image we want to write (I think this is the right size?)
#define IMGSIZE 4096
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

// Reads the file into data
void readfile(const std::string& file, std::string& data);

// Writes memory to a file
void writefile(const std::string& outfile);

// Creates all the labels
// What else??
void firstpass(const std::string& assembly);

// Translates into machine code
void secondpass(const std::string& assembly);

void createreservedwords();

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

	createreservedwords();

	// the string to store the unparsed file into
	std::string assembly;
	readfile(file,assembly);

	firstpass(assembly);
	secondpass(assembly);

	writefile(out);
}

void readfile(const std::string& file, std::string& data) {
	using namespace std;
	ifstream ifs;
	ifs.open(file.c_str(),ios::binary);

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
	of << "WIDTH = 16;\n"; // Change if INSTRSIZE changes
	of << "DEPTH = " << IMGSIZE <<" ;\n";
	of << "ADDRESS_RADIX = UNS;\n";		// unsigned decimal
	of << "DATA_RADIX = UNS;\n";	// unsigned decimal with WIDTH bits

	of << "CONTENT BEGIN\n";

	for(unsigned int i = 0; i < IMGSIZE; ++i)
		of << '\t' << i << "\t:\t" << memory[i] << ";\n";

	of << "END;\n";

	of.close();
}

void firstpass(const std::string& assembly) {
	using namespace std;
	stringstream is(assembly, stringstream::in | stringstream::out);

	string token;
	unsigned long int index;
	unsigned int i;
	unsigned long int address = 0;

	// Read each token
	while(is.good()) {
		is >> token;

		if((index = token.find(':',0)) != -1) {
			string label = token.substr(0,index);

			if(!label.compare(".ORG")) {
				is >> address;
				continue;
			}
			else if(!label.compare(".DATA")) {
				is >> token;
				++address;
				continue;
			}

			for(i = 0; i < labels.size(); ++i) {
				if(!label.compare(labels[i].first))
					break;
			}

			if(i == labels.size())	// If label has not been initialized before, add it to the labels vector
				labels.push_back(pair<string,INSTRSIZE>(label,address));
		}
		else {

			// Count instructions
			for(i = 0; i < reservedwords.size(); ++i) {
				if(token.compare(reservedwords[i].first) == 0) { // matching instruction?
					if(i < totalinstrs)
						++address;
					break;
				}
			}
		}
	}

	// Test label table
	//for(unsigned int i = 0; i < labels.size(); i++)
		//cout << labels[i].first << " " << labels[i].second << "\n";
}

// This could probably divided up into multiple functions, but I'm lazy right now
// I'll do it later if things become much more complicated
void secondpass(const std::string& assembly) {
	using namespace std;
	istringstream is(assembly, stringstream::in | stringstream::out);

	string token;
	unsigned long int instrcnt = 0;

	// Read each token
	while(is.good()) {
		is >> token;
		if(!is.good())
			break;
		
		if(token.find(';',0) == 0) { // Found a comment
			if(is.good())
				getline(is,token);
		}
		else if(token.find(':',0) != -1); // In the second pass we just want to ignore labels
		else {
			// We use this to help detect invalid code
			unsigned long int oldcount = instrcnt;

			// Find instruction and handle it
			for(unsigned int i = 0; i < totalinstrs; ++i) {
				if(token.compare(reservedwords[i].first) == 0) { // matching instruction?
					++instrcnt;

					string instruction = reservedwords[i].first;
					INSTRSIZE instr = reservedwords[i].second;
					if(instr == -1) { // We found a psuedo-instruction or something else
						// For the time being, just ignore the line
						if(is.good())
							getline(is,token);
					}

					// Next comes a register
					if(is.good())
						is >> token;
					else
						cout << "Error: Incomplete file?" << endl;

					// All registers are strings of length 2
					string reg = token.substr(0,2);

					for(unsigned int j = 0; j < reservedwords.size(); ++j) {
						if(reg.compare(reservedwords[j].first) == 0) {
							instr = instr | (reservedwords[j].second << 10);
							break;
						}
					}

					// Next comes a register
					if(is.good())
						is >> token;
					else
						cout << "Error: Incomplete file?" << endl;

					// All registers are strings of length 2
					reg = token.substr(0,2);

					for(unsigned int j = 0; j < reservedwords.size(); ++j) {
						if(reg.compare(reservedwords[j].first) == 0) {
							instr = instr | (reservedwords[j].second << 7);
							break;
						}
					}
					
					// Next comes a register
					if(is.good())
						is >> token;
					else
						cout << "Error: Incomplete file?" << endl;

					// All registers are strings of length 2
					reg = token.substr(0,2);

					for(unsigned int j = 0; j < reservedwords.size(); ++j) {
						if(reg.compare(reservedwords[j].first) == 0) {
							instr = instr | (reservedwords[j].second << 4);
							break;
						}
					}


					cout << hex << instr << endl;


				}
			}
			// Incorrect code! (or a bug above)
			if(oldcount == instrcnt) {
				cout << "Error: " << token << " is not an instruction!" << endl;
				//exit(1);
			}
		}
	}
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
