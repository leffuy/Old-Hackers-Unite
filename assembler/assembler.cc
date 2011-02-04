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

	// Write the entire file at once
	// IMGSIZE*2 because this writes in bytes, and memory is a short array
	of.write((char*)memory,IMGSIZE*2);

	of.close();
}

void firstpass(const std::string& assembly) {
	using namespace std;
	stringstream is(assembly, stringstream::in | stringstream::out);

	string token;
	unsigned long int instrcnt = 0;

	// Read each token
	while(is.good()) {
		is >> token;

		if(token.find(':',0) != -1) {
			string nexttoken;
			if(is.good()) {
				is >> nexttoken;
			}
			// Are we on a line with a new instruction?
			for(unsigned int i = 0; i < totalinstrs; ++i) {
				if(nexttoken.compare(reservedwords[i].first) == 0) // matching instruction?
					++instrcnt;
			}

			// add label
			labels.push_back(pair<string,INSTRSIZE>(token.substr(0,token.length()-1),instrcnt));
	
			// Reset things so we can continue safely
			--instrcnt; 
			is << nexttoken;

		}
		else {
			// Count instructions
			for(unsigned int i = 0; i < totalinstrs; ++i) {
				if(token.compare(reservedwords[i].first) == 0) // matching instruction?
					++instrcnt;
			}
		}
	}
}

void secondpass(const std::string& assembly) {
	using namespace std;
	istringstream is(assembly, stringstream::in | stringstream::out);

	string token;
	unsigned long int instrcnt = 0;

	// Read each token
	while(is.good()) {
		is >> token;
		
		if(token.find(':',0) != -1); // In the second pass we just want to ignore labels
		else {
			// We use this to help detect invalid code
			unsigned long int oldcount = instrcnt;

			// Find instruction and handle it
			for(unsigned int i = 0; i < totalinstrs; ++i) {
				if(token.compare(reservedwords[i].first) == 0) { // matching instruction?
					++instrcnt;

					// Translate instruction into machine code
				}
			}
			// Incorrect code! (or a bug above)
			if(oldcount == instrcnt) {
				cout << "Error: " << token << "is not an instruction!" << endl;
				exit(1);
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
