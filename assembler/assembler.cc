#include <iostream>
#include <sstream>
#include <fstream>

#include <boost/program_options.hpp>

// Storage for the memory image we want to write (I think this is the right size?)
#define IMGSIZE 4096
short memory[IMGSIZE];

// A resizable array for the tokens after parsing the file
std::vector<short> tokens;

// Reads the file into data
void readfile(const std::string& file, std::string& data);

// Parses the string into tokens
void parse(const std::string& assembly);

// Writes memory to a file
void writefile(const std::string& outfile);

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
		/* Uncomment this once we have something we need to save
		else {
			std::cout << "No file to save to! See --help.\n";
			return 1;
		}
		*/
	}

	// the string to store the unparsed file into
	std::string assembly;
	readfile(file,assembly);

	parse(assembly);

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

}

void parse(const std::string& assembly) {
	
}
