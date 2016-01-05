import std.stdio;
import std.algorithm;
import std.array;
import std.range;
import std.string;
import std.file : dirEntries, SpanMode;

void main()
{
	foreach(fileName; dirEntries("./", "*.obj", SpanMode.depth))
	{
		auto obj = File(fileName).byLineCopy.array;
		auto outFile = File(fileName, "w");
		
		foreach(line; obj.map!updateLine)
		{
			outFile.writeln(line);
		}
	}
}

string updateLine(string line)
{
	auto splitLine = line.split(" ");
	
	if(splitLine.length == 0) return line;
	
	switch(splitLine[0])
	{
		case "v":
		return "v " ~ splitLine[1] ~ " " ~ splitLine[3] ~ " " ~ splitLine[2];
		case "f":
		return "f " ~ splitLine[1 .. $].retro.join(" ");
		default:
		return line;
	}
}