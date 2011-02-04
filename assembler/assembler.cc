#include <iostream>
#include <sstream>
#include <fstream>

#include <boost/program_options.hpp>

char memory[4096];
std::vector tokens;

void readfile(const std::string& file, std::string& data);
void parse(const std::string& assembly);

int main(int argc, char* argv[]) {

	std::string file,out;

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

		if( vm.count("file") )
			file=vm["file"].as<std::string>();
		if( vm.count("out") )
			out=vm["out"].as<std::string>();
	}

	std::string assembly;
	readfile(file,assembly);

	parse(assemmbly);

}

void readfile(const std::string& file, std::string& data) {
	using namespace std;
	ifstream ifs;
	ifs.open(file.c_str(),ios::binary);

	ifs.seekg(0,ios::end);
	long int length = ifs.tellg();
	ifs.seekg(0,ios::beg);

	char buf[length];

	ifs.read(buf,length);
	ifs.close();

	data.assign(buf,length);
	cout << data << endl;
}



void parse(const std::string& assembly) {
	
}
