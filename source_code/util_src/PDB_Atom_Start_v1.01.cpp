#include <string>
#include <stdlib.h>
#include <string.h>
#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <cmath>
#include <map>
#include <algorithm>
using namespace std;


//------- int2string -----//
string convertInt(int number)
{
	stringstream ss;  //create a stringstream
	ss << number;     //add number to the stream
	return ss.str();  //return a string with the contents of the stream
}


//========== process PDB ============//
void PDB_Atom_Trans(string &pdbfile,FILE *fp,int start) //->from .pdb file
{
	ifstream fin;
	string buf,temp;
	//read
	fin.open(pdbfile.c_str(), ios::in);
	if(fin.fail()!=0)
	{
		fprintf(stderr,"pdbfile %s not found!!\n",pdbfile.c_str());
		exit(-1);
	}
	int pos;
	int len;
	int count=start;
	for(;;)
	{
		if(!getline(fin,buf,'\n'))break;
		len=(int)buf.length();
		if(len>=4)
		{
			temp=buf.substr(0,4);
			if(temp=="ATOM"||temp=="HETA")
			{
				string pos_str=convertInt(count);
				count++;
				string part1=buf.substr(0,5);
				string part2=buf.substr(11,len-11);
				fprintf(fp,"%s%6s%s\n",part1.c_str(),pos_str.c_str(),part2.c_str());
			}
			else fprintf(fp,"%s\n",buf.c_str());
		}
		else fprintf(fp,"%s\n",buf.c_str());
	}
}

//---------- main ----------//
int main(int argc,char **argv)
{
	//---- PDB_Residue_Trans ----//
	{
		if(argc<4)
		{
			fprintf(stderr,"Version 1.01 \n");
			fprintf(stderr,"PDB_Atom_Start <pdbfile> <start_pos> <outfile> \n");
			fprintf(stderr,"[note]: input PDB_file and start position, \n");
			fprintf(stderr,"        begin the atom numbering of PDB_file according to the start position. \n");
			exit(-1);
		}
		string infile=argv[1];
		int start_pos=atoi(argv[2]);
		string outfile=argv[3];
		FILE *fp=fopen(outfile.c_str(),"wb");
		PDB_Atom_Trans(infile,fp,start_pos);
		fclose(fp);
		exit(0);
	}
}
