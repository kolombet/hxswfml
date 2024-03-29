package be.haxer.hxswfml;

import be.haxer.hxswfml.ShapeWriter;

import format.swf.Data;
import format.ttf.Data;
import format.zip.Data;

import format.ttf.Tools;
import format.swf.Writer;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;

/**
 * ...
 * @author Jan J. Flanders
 */
typedef GlyphData=
{
	var charCode:Int;
	var ascent:Float;
	var descent:Float;
	var leading:Float;
	var advanceWidth:Float;
	var leftsideBearing:Float;
	var xMin:Float;
	var xMax:Float;
	var yMin:Float;
	var yMax:Float;
	var _width:Float;
	var _height:Float;
	var commands:Array<Int>;
	var data:Array<Float>;
}
class FontWriter
{
	public var fontName :String;
	
	var zip:Bytes;
	var swf:Bytes;
	var path:String;
	var hash:Map<Int,GlyphData>;
	var chars:Array<Int>;
	var outputType:String;
	var fontData3:FontData;
	var defineFont3SWFTag:SWFTag;
	var leading:Int;
	public var precision:Int;
	
	var zipResources_charClass:String;
	var zipResources_mainClass:String;
	var zipResources_buildFile:String;

	public function new()
	{
		init();
	}
	public function listGlyphs(bytes:Bytes):String
	{
		var input = new BytesInput(bytes);
		var reader = new format.ttf.Reader(input);
		var ttf:TTF = reader.read();
		var tables = ttf.tables;
		var cmapData=null;
		var glyfData=null;
		var dump = new StringBuf();
		
		for(table in tables)
		{
			switch(table)
			{
				case TGlyf(descriptions): glyfData = descriptions;
				case TCmap(subtables): cmapData = subtables;
				default:
			}
		}
		dump.add("fontName = " + reader.fontName + "\n\n");
		dump.add("charCodes = " + '"' + getAllRange(tables) + '"' + "\n");
		
		var glyphIndexArray:Array<GlyphIndex>=new Array();
		for(s in cmapData)
		{
			switch(s)
			{
				case Cmap4(header, array):
					glyphIndexArray = array;
					break;
				default: 
			}
		}
		if(glyphIndexArray.length==0)
			throw("ERROR: Cmap4 encoding table not found");
		
		for(i in 0...glyphIndexArray.length-1)
		{
			if(glyphIndexArray[i]!=null)
			{
				var index = glyphIndexArray[i].index;
				dump.add("\nglyphIndexArray[");
				dump.add(i);
				dump.add("]= charCode= " );
				dump.add( glyphIndexArray[i].charCode );
				dump.add( " char= " );
				dump.add( glyphIndexArray[i].char );
				dump.add( "\n" );
				dump.add("index= " );
				dump.add( glyphIndexArray[i].index );
				dump.add( " = glyfData[" );
				dump.add( index );
				dump.add( "]= " );
				dump.add( glyfData[index] );
				dump.add( "\n" );
			}
		}
		return dump.toString();
	}
	public function writeOTF(id:Int, name:String, bytes:Bytes):SWFTag
	{
		var input = new BytesInput(bytes);
		var otf = format.ttf.Reader.readOTF(input);
		var header = otf.header;
		var tables = otf.tables;
		var cffFound:Bool=false;
		for(t in tables)
		{
			t.bytes = bytes.sub(t.offset, t.length);
			if(t.tableName=="CFF ")
				cffFound=true;
		}
		if(cffFound==false)
			return null;
		var output = new BytesOutput();
		for(t in tables)
		{
			switch(t.tableName)
			{
				case 
					"CFF ", "cmap", "head", "maxp", "OS/2", "post",
					"hhea", "hmtx",
					"vhea", "vmtx", "VORG",
					"GSUB", "GPOS", "GDEF", "BASE":
						output.write(t.bytes);
				default:
			}
		}
		var font4Data = 
		{
			hasSFNT:true,
			isItalic: false,
			isBold: false,
			name: name,
			bytes : bytes
		};
		return TFont(id, FDFont4(font4Data));
	}
	public function write(bytes:Bytes, rangesStr:String, outType:String='swf', ?fontName:String)
	{
		var input = new BytesInput(bytes);
		var reader = new format.ttf.Reader(input);
		var ttf:TTF = reader.read();
		chars=new Array();
		
		var header = ttf.header;
		var tables = ttf.tables;
		var allRange = getAllRange(ttf.tables);
		var glyfData=null;
		var hmtxData=null;
		var cmapData=null;
		var kernData=null;
		var hheaData=null;
		var headData=null;
		var os2Data=null;

		for(table in tables)
		{
			switch(table)
			{
				case TGlyf(descriptions): glyfData = descriptions;
				case THmtx(metrics): hmtxData = metrics;
				case TCmap(subtables): cmapData = subtables;
				case TKern(kerning): kernData = kerning;
				case THhea(data): hheaData=data;
				case THead(data): headData = data;
				case TOS2(data): os2Data = data;
				default:
			}
		}
		if(os2Data==null) os2Data = cast {usWinAscent:hheaData.ascender, usWinDescent:hheaData.descender};
		this.fontName = fontName!=null? fontName : reader.fontName;
		var scale = 1024/headData.unitsPerEm;
		var glyphIndexArray:Array<GlyphIndex>=new Array();
		for(s in cmapData)
		{
			switch(s)
			{
				case Cmap4(header, array):
					glyphIndexArray = array;
					break;
				default: 
			}
		}
		if(glyphIndexArray.length==0)
			throw 'Cmap4 encoding table not found';

		var charCodes:Array<Int> = new Array();
		var ranges /*:Array<format.ttf.Data.UnicodeRange>*/ = new Array();
		if(rangesStr=="all")
		{
			rangesStr = getAllRange(tables);
		}
		
		var parts:Array<String> = rangesStr.split('[').join("").split(']').join("").split(' ').join('').split(',');
		for(i in 0... parts.length)
		{
			if(parts[i].indexOf('-')==-1)
				ranges.push({start:Std.parseInt(parts[i]), end:Std.parseInt(parts[i])});
			else
				ranges.push({start:Std.parseInt(parts[i].split('-')[0]), end:Std.parseInt(parts[i].split('-')[1])});
		}

		switch(outType)
		{
			case 'swf', 'zip', 'path', 'hash': outputType = outType;
			default : throw 'Unknown output type';
		}
		
		//format.zip setup
		var zipBytesOutput = new BytesOutput();
		var zipWriter = new format.zip.Writer(zipBytesOutput);
		var zipdata:List<format.zip.Entry> = new List();

		//format.swf setup
		var glyphs:Array<format.swf.Data.Font2GlyphData>=new Array();
		var glyphLayouts:Array<FontLayoutGlyphData>= new Array();
		var kerning:Array<FontKerningData>=new Array();
		var lastCharCode:Int=0;
		
		//path setup
		var charObjects:Array<Dynamic>=new Array();
		
		//hash setup
		var charHash:Map<Int,GlyphData> = new Map();
		
		var importsBuf:StringBuf=new StringBuf();
		var graphicsBuf:StringBuf=new StringBuf();
		var varsBuf:StringBuf=new StringBuf();
		var commands:Array<Int>;
		var datas:Array<Float>;
		for(i in 0...ranges.length)
		{
			if(ranges[i].start>ranges[i].end)
				throw 'Character ranges must be ascending and non overlapping, '+ranges[i].start +' should be lower than '  +ranges[i].end;
			if(ranges[i-1]!=null && ranges[i].start <= ranges[i-1].end) 
				throw 'Character ranges must be ascending and non overlapping, '+ranges[i].start +' should be higher than '  +ranges[i-1].end;
			
			for(j in ranges[i].start...ranges[i].end+1)
			{
				commands = new Array();
				datas = new Array();
				graphicsBuf = new StringBuf();
				varsBuf=new StringBuf();
			
				var charCode:Int = j;
				chars.push(j);

				var glyphIndex:Int;
				var idx:GlyphIndex = glyphIndexArray[j];
				glyphIndex = 0;
				if(idx!=null)
					glyphIndex = idx.index;

				var advanceWidth = hmtxData[glyphIndex]==null?hmtxData[0].advanceWidth : hmtxData[glyphIndex].advanceWidth;
				var leftSideBearing:Int = hmtxData[glyphIndex]==null?hmtxData[0].leftSideBearing : hmtxData[glyphIndex].leftSideBearing;

				var shapeRecords: Array<ShapeRecord> = new Array();
				var shapeWriter:ShapeWriter=new ShapeWriter(false);
				var header:GlyphHeader=null;
				var prec:Int = Std.int(Math.pow(10, Std.int(this.precision))); 
				switch(glyfData[glyphIndex])
				{
					case TGlyphNull: 
						glyphs.push({charCode:charCode, shape:{shapeRecords: [SHREnd]}});
						glyphLayouts.push({advance:Std.int(advanceWidth*scale*20), bounds:{left:0, right:0, top:0, bottom:0}});
						shapeWriter.reset(false);
					
					case TGlyphComposite(_header, data):
						var paths1=[];
						var paths2=[];
						if (!(data[0]==null && data[1]==null))
						{
							header = _header;
							if(data[0]!=null)
							{
								var c1 = data[0];
								var part1 = glyfData[c1.glyphIndex];
								var dat1:GlyphSimple = Type.enumParameters(part1)[1];
								if(dat1==null) continue;
								var dat1bis:GlyphSimple={endPtsOfContours:[],instructions:[],xCoordinates:[],yCoordinates:[],flags:dat1.flags, xDeltas:[], yDeltas:[]}
								if(dat1.endPtsOfContours != null)
									for(i in dat1.endPtsOfContours) dat1bis.endPtsOfContours.push(i);
								if(dat1.instructions != null)
									for(i in dat1.instructions) dat1bis.instructions.push(i);
								if(dat1.xCoordinates != null)
									for(i in dat1.xCoordinates) dat1bis.xCoordinates.push(c1.xtranslate!=null? i+c1.xtranslate : i);
								if(dat1.yCoordinates != null)
									for(i in dat1.yCoordinates) dat1bis.yCoordinates.push(c1.ytranslate!=null? i+c1.ytranslate : i);
								paths1 = buildPaths(dat1bis);
							}
							if(data.length > 1 && data[1]!=null)
							{
								var c2 = data[1];
								var part2 = glyfData[c2.glyphIndex];
								var dat2:GlyphSimple = Type.enumParameters(part2)[1];
								var dat2bis:GlyphSimple={endPtsOfContours:[],instructions:[],xCoordinates:[],yCoordinates:[],flags:dat2.flags, xDeltas:[], yDeltas:[]}
								for(i in dat2.endPtsOfContours)	dat2bis.endPtsOfContours.push(i);
								for(i in dat2.instructions)	dat2bis.instructions.push(i);
								for(i in dat2.xCoordinates)	dat2bis.xCoordinates.push(c2.xtranslate!=null? i+c2.xtranslate : i);
								for(i in dat2.yCoordinates)	dat2bis.yCoordinates.push(c2.ytranslate!=null? i+c2.ytranslate : i);
								paths2 = buildPaths(dat2bis);
							}
							var paths : Array<GlyfPath> = paths1.concat(paths2);
							writePaths([outputType, paths, shapeWriter,scale,prec,graphicsBuf,commands,datas,shapeRecords,glyphs,charCode,glyphLayouts,advanceWidth]);
						}
					case TGlyphSimple(_header, data):
						header = _header;
						var paths:Array<GlyfPath> = buildPaths(data);
						writePaths([outputType, paths, shapeWriter,scale,prec,graphicsBuf,commands,datas,shapeRecords,glyphs,charCode,glyphLayouts,advanceWidth]);
				}
				if(header==null) 
					header = {numberOfContours:0, xMin:0, xMax:0, yMin:0, yMax:0};
				
				//path output:
				if(outputType=="path" || outputType=="hash")
				{
					var charObj = 
					{
						charCode:j,
						ascent:Std.int(os2Data.usWinAscent * scale * prec)/prec,
						descent:Std.int(os2Data.usWinDescent * scale * prec)/prec,
						leading:Std.int((os2Data.usWinAscent + os2Data.usWinDescent - headData.unitsPerEm) *scale * prec)/prec,
						advanceWidth:Std.int(advanceWidth*scale* prec)/prec,
						leftsideBearing:Std.int(leftSideBearing*scale* prec)/prec,
						xMin:Std.int(header.xMin*scale* prec)/prec,
						xMax:Std.int(header.xMax*scale* prec)/prec,
						yMin:Std.int(header.yMin*scale* prec)/prec,
						yMax:Std.int(header.yMax*scale* prec)/prec,
						_width:Std.int(advanceWidth*scale* prec)/prec,
						_height:Std.int((header.yMax - header.xMin)*scale* prec)/prec,
						commands:commands,
						data:datas
					}
					charObjects.push(charObj);
					charHash.set(Std.int(j), charObj);
				}
				//zip output:
				if(outputType=='zip')
				{
					charCodes.push(j);
					importsBuf.add("import Char");
					importsBuf.add(j);
					importsBuf.add(";\n");
					
					varsBuf.add("\tpublic static inline var ascent = "); varsBuf.add(Std.int(os2Data.usWinAscent * scale * prec)/prec);
					varsBuf.add(";\n\tpublic static inline var descent = "); varsBuf.add(Std.int(os2Data.usWinDescent * scale * prec)/prec);
					varsBuf.add(";\n\tpublic static inline var leading = "); varsBuf.add((Std.int((os2Data.usWinAscent + os2Data.usWinDescent - headData.unitsPerEm) *scale * prec)/prec));
					varsBuf.add(";\n\tpublic static inline var advanceWidth = "); varsBuf.add(Std.int(advanceWidth*scale* prec)/prec);
					varsBuf.add(";\n\tpublic static inline var leftsideBearing = "); varsBuf.add(Std.int(leftSideBearing*scale* prec)/prec);
					varsBuf.add(";\n");
					
					varsBuf.add("\n\tpublic static inline var xMin = "); varsBuf.add(Std.int(header.xMin*scale* prec)/prec);
					varsBuf.add(";\n\tpublic static inline var xMax = "); varsBuf.add(Std.int(header.xMax*scale* prec)/prec);
					varsBuf.add(";\n\tpublic static inline var yMin = "); varsBuf.add(Std.int(header.yMin*scale* prec)/prec);
					varsBuf.add(";\n\tpublic static inline var yMax = "); varsBuf.add(Std.int(header.yMax*scale* prec)/prec);
					
					varsBuf.add(";\n");
					varsBuf.add("\n\tpublic static inline var _width = "); varsBuf.add(Std.int(advanceWidth*scale* prec)/prec);
					varsBuf.add(";\n\tpublic static inline var _height = "); varsBuf.add(Std.int((header.yMax - header.xMin)*scale* prec)/prec);
					varsBuf.add(";");
					
					var charClass = zipResources_charClass;
					charClass = charClass.split("#C").join(String.fromCharCode(j));
					charClass = charClass.split("#0").join(Std.string(j));
					charClass = charClass.split("#commands").join(#if flash "[" +#end commands.toString() #if flash +"]" #end );
					charClass = charClass.split("#datas").join(#if flash "[" +#end datas.toString() #if flash +"]" #end );
					charClass = charClass.split("#1").join(varsBuf.toString());
					charClass = charClass.split("#2").join(graphicsBuf.toString());
					zipdata.add(
					{
						fileName : 'Char'+j+'.hx', 
						fileSize : charClass.length, 
						fileTime : Date.now(), 
						compressed : false, 
						dataSize : charClass.length,
						data : Bytes.ofString(charClass),
						crc32 : haxe.crypto.Crc32.make(Bytes.ofString(charClass)),
						extraFields : new List()
					});
				}
			}
			lastCharCode = ranges[i].end;
		}
		var kerning = [];
		for (i in 0...kernData.length)
		{
			var table = kernData[i];
			switch(table)
			{
				case KernSub0(kerningPairs):
					for (pair in kerningPairs)
					{
						if(pairInRange(pair))
							kerning.push({charCode1:pair.left,	charCode2:pair.right,	adjust:Std.int(pair.value*scale*20)});
					}
				default:
			}
		}
		
		//SWFTAG OUTPUT
		leading = Std.int( (os2Data.usWinAscent + os2Data.usWinDescent - headData.unitsPerEm) *scale *20);
		var fontLayoutData = 
		{
			ascent: Std.int(os2Data.usWinAscent * scale * 20) , 
			descent: Std.int(os2Data.usWinDescent * scale * 20) ,
			leading: leading,
			glyphs: glyphLayouts,
			kerning:kerning 
		}
		var font2Data= 
		{
			shiftJIS: false,
			isSmall: false,
			isANSI: false,
			isItalic:false,
			isBold: false,
			language: LangCode.LCNone,//LangCode.LCLatin,//,
			name: this.fontName,
			glyphs: glyphs,
			layout:fontLayoutData
		}
		var hasWideChars=true;
		fontData3 = FDFont3(font2Data);
		defineFont3SWFTag = TFont(1, FDFont3(font2Data));
		
		//ZIP OUTPUT:
		if(outputType=='zip')
		{
			
			var mainClass = zipResources_mainClass;
			mainClass = mainClass.split("#0").join( #if flash "[" +#end charCodes.toString() #if flash +"]" #end );
			mainClass = mainClass.split("#1").join(importsBuf.toString());
			zipdata.add(
			{
						fileName : 'Main.hx', 
						fileSize : mainClass.length, 
						fileTime : Date.now(), 
						compressed : false, 
						dataSize : mainClass.length,
						data : Bytes.ofString(mainClass),
						crc32 : haxe.crypto.Crc32.make(Bytes.ofString(mainClass)),
						extraFields : new List()
			});
			var buildFile = zipResources_buildFile;
			buildFile = buildFile.split("#0").join(this.fontName);
			zipdata.add(
			{
						fileName : 'build.hxml', 
						fileSize : buildFile.length, 
						fileTime : Date.now(), 
						compressed : false, 
						dataSize : buildFile.length,
						data : Bytes.ofString(buildFile),
						crc32 : haxe.crypto.Crc32.make(Bytes.ofString(buildFile)),
						extraFields : new List()
			});
			
			zipWriter.writeData( zipdata );
			zip = zipBytesOutput.getBytes();
		}
		//path OUTPUT:
		if(outputType=='path')
		{
			var index=0;
			var buf = new StringBuf();
			buf.add('//Usage: see example below \n\n');
			buf.add('var ');
			buf.add(this.fontName);
			buf.add('=\n{\n');
			
			for(char in charObjects)
			{
				buf.add('\tchar');
				buf.add(char.charCode );
				buf.add(':\t/* ');
				buf.add(String.fromCharCode(char.charCode));
				buf.add(' */');
				buf.add('\n\t{\n\t\tascent:');
				buf.add(char.ascent);
				buf.add(', descent:');
				buf.add(char.descent);
				buf.add(', advanceWidth:');
				buf.add(char.advanceWidth);
				buf.add(', leftsideBearing:');
				buf.add(char.leftsideBearing);
				buf.add(', xMin:');
				buf.add(char.xMin);
				buf.add(', xMax:');
				buf.add(char.xMax);
				buf.add(', yMin:');
				buf.add(char.yMin);
				buf.add(', yMax:');
				buf.add(char.yMax);
				buf.add(', _width:');
				buf.add(char._width);
				buf.add(', _height:');
				buf.add(char._height);
				buf.add(',\n\t\tcommands:');
				buf.add(#if flash "[" + #end char.commands.toString() #if flash +"]" #end);
				buf.add(',\n\t\tdata:');
				buf.add(#if flash "[" + #end char.data.toString() #if flash +"]" #end);
				if(index++<charObjects.length-1)
					buf.add('\n\t},\n');
				else
					buf.add('\n\t}\n');
			}
			buf.add('}\n');
			buf.add('//-------------------------------------------------------------------------\n');
			buf.add('//Example:\n');
			buf.add('var s=new Sprite();\n');
			buf.add('s.graphics.lineStyle(2,1);//s.graphics.beginFill(0,1);\n');
			buf.add('s.graphics.drawPath(Vector.<int>(');
			buf.add(this.fontName);
			buf.add('.char35.commands), Vector.<Number>(');
			buf.add(this.fontName);
			buf.add('.char35.data), flash.display.GraphicsPathWinding.EVEN_ODD);\n');
			buf.add('s.scaleX=s.scaleY = 0.1;\n');
			buf.add('addChild(s);');
			path = buf.toString();
		}
		if(outputType=='hash')
		{
			hash = charHash;
		}
	}
	function writePaths(arr:Array<Dynamic>):Void //outputType:String, paths:Array<GlyfPath>, shapeWriter:ShapeWriter, scale:Float, prec:Int, graphicsBuf:StringBuf, commands:Array<Int>, datas:Array<Float>, shapeRecords:Array<ShapeRecord>, glyphs:Array<format.swf.Data.Font2GlyphData>, charCode:Int, glyphLayouts:Array<FontLayoutGlyphData>, advanceWidth:Int):Void
	{
		var outputType:String = arr[0];
		var paths:Array<GlyfPath>= arr[1];
		var shapeWriter:ShapeWriter= arr[2]; 
		var scale:Float= arr[3]; 
		var prec:Int= arr[4]; 
		var graphicsBuf:StringBuf= arr[5]; 
		var commands:Array<Int>= arr[6]; 
		var datas:Array<Float>= arr[7]; 
		var shapeRecords:Array<ShapeRecord>= arr[8]; 
		var glyphs:Array<format.swf.Data.Font2GlyphData>= arr[9]; 
		var charCode:Int= arr[10]; 
		var glyphLayouts:Array<FontLayoutGlyphData>= arr[11]; 
		var advanceWidth:Int= arr[12];
		if(outputType =='swf')
			shapeWriter.beginFill(0,1);
		for(i in 0...paths.length)
		{
			var path:GlyfPath = paths[i];
			switch(path.type)
			{
				case 0:
					switch (outputType)
					{
						case 'zip':
							var x = Std.int((path.x * scale)*prec)/prec;
							var y = Std.int((1024 - path.y * scale)*prec)/prec;
							graphicsBuf.add( "\t\t\tgraphics.moveTo(");
							graphicsBuf.add(Std.string(x));
							graphicsBuf.add(", ");
							graphicsBuf.add(Std.string(y));
							graphicsBuf.add(");\n");
							commands.push(1);
							datas.push(x);
							datas.push(y);

						case 'path', 'hash':
							var x = Std.int((path.x * scale)*prec)/prec;
							var y = Std.int((1024 - path.y * scale)*prec)/prec;
							commands.push(1);
							datas.push(x);
							datas.push(y);

						case 'swf':
							shapeWriter.moveTo(path.x * scale, -1 * path.y * scale);
					}
				case 1:
					switch(outputType)
					{
						case 'zip':
							var x = Std.int((path.x * scale)*prec)/prec;
							var y = Std.int((1024 - path.y * scale)*prec)/prec;
							graphicsBuf.add( "\t\t\tgraphics.lineTo(");
							graphicsBuf.add(Std.string(x));
							graphicsBuf.add( ", " ); 
							graphicsBuf.add(Std.string(y)); 
							graphicsBuf.add(");\n");
							commands.push(2);
							datas.push(x);
							datas.push(y);

						case 'path', 'hash':
							var x = Std.int((path.x * scale)*prec)/prec;
							var y = Std.int((1024 - path.y * scale)*prec)/prec;
							commands.push(2);
							datas.push(x);
							datas.push(y);

						case 'swf':
							shapeWriter.lineTo(path.x * scale, -1 * path.y*scale);
					}
				case 2:
					switch (outputType)
					{
						case 'zip':
							var cx = Std.int((path.cx * scale)*prec)/prec;
							var cy = Std.int((1024 - path.cy * scale)*prec)/prec;
							var x = Std.int((path.x * scale)*prec)/prec;
							var y = Std.int((1024 - path.y * scale)*prec)/prec;
							graphicsBuf.add( "\t\t\tgraphics.curveTo(" );
							graphicsBuf.add(Std.string(cx));
							graphicsBuf.add(", "); 
							graphicsBuf.add(Std.string(cy));
							graphicsBuf.add(", " );
							graphicsBuf.add(Std.string(x));
							graphicsBuf.add(", " );
							graphicsBuf.add(Std.string(y));
							graphicsBuf.add(");\n");
							commands.push(3);
							datas.push(cx);
							datas.push(cy);
							datas.push(x);
							datas.push(y);

						case 'path', 'hash':
							var cx = Std.int((path.cx * scale)*prec)/prec;
							var cy = Std.int((1024 - path.cy * scale)*prec)/prec;
							var x = Std.int((path.x * scale)*prec)/prec;
							var y = Std.int((1024 - path.y * scale)*prec)/prec;
							commands.push(3);
							datas.push(cx);
							datas.push(cy);
							datas.push(x);
							datas.push(y);

						case 'swf':
							shapeWriter.curveTo(path.cx * scale, -1 * path.cy * scale, path.x * scale, -1 * path.y * scale);
					}
			}
		}
		var shapeRecs:Array<ShapeRecord> = shapeWriter.getShapeRecords();
		for(s in 0...shapeRecs.length)
			shapeRecords.push(shapeRecs[s]) ;
		shapeRecords.push(SHREnd);
		glyphs.push({charCode:charCode, shape:{shapeRecords: shapeRecords}});
		glyphLayouts.push({advance:Std.int(advanceWidth*scale*20), bounds:{left:0, right:0, top:0, bottom:0}});
		shapeWriter.reset(false);
	}
	public function getPath():String
	{
		return path;
	}
	public function getZip():Bytes
	{
		return zip;
	}
	public function getHash(?serialize:Bool=false):Dynamic
	{
		if(serialize)
		{
			return haxe.Serializer.run(hash);
		}
		return hash;
	}
	public function getTag(id:Int):SWFTag
	{
		return TFont(id, fontData3 );
	}
	public function getSWF(id:Int=1, className:String="MyFont", version:Int=10, compressed :Bool= false, width :Int =1000, height :Int =1000, fps :Int =30, nframes :Int =1):Bytes
	{
		var initialText = "";
		var textColor = 0x000000FF;
		for(i in 0...chars.length)
			initialText+=String.fromCharCode(chars[i]);
		initialText+=' Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.';
		var defineEditTextTag = TDefineEditText
		(
			id+1, 
			{
				bounds : {left : 0, right : 1024 * 20, top : 0,  bottom : 1024 * 20}, 
				hasText :  true , 
				hasTextColor : true, 
				hasMaxLength : false, 
				hasFont : true, 
				hasFontClass :false, 
				hasLayout : true,
				
				wordWrap : true, 
				multiline : true, 
				password : false, 
				input : false,	
				autoSize : false, 
				selectable : false, 
				border : true, 
				wasStatic : false,
				
				html : false,
				useOutlines : true,
				fontID : id,
				fontClass : "",
				fontHeight : 24* 20,
				textColor:
				{
					r : (textColor & 0xff000000) >> 24, 
					g : (textColor & 0x00ff0000) >> 16, 
					b : (textColor & 0x0000ff00) >>  8, 
					a : (textColor & 0x000000ff) 
				},
				maxLength : 0,
				align : 0,
				leftMargin : 0 * 20,
				rightMargin : 0 * 20,
				indent :  0 * 20,
				leading : Std.int(leading/20),
				variableName : "",
				initialText: initialText
			}
		);
		var placeObject : PlaceObject = new PlaceObject();
		placeObject.depth = 1;
		placeObject.move = false ;
		placeObject.cid = id+1;
		placeObject.matrix = {scale:null, rotate:null, translate:{x:0, y:100*20}};
		placeObject.color = null;
		placeObject.ratio = null;
		placeObject.instanceName = "tf";
		placeObject.clipDepth = null;
		placeObject.events = null;
		placeObject.filters = null;
		placeObject.blendMode = null;
		placeObject.bitmapCache = null;

		var swfFile = 
		{
			header: {version:version, compressed:compressed, width:width, height:height, fps:fps, nframes:nframes},
			tags: 
			[
				TSandBox({useDirectBlit :false, useGPU:false, hasMetaData:false, actionscript3:true, useNetWork:false}), 
				TBackgroundColor(0xffffff),
				TFont(id, fontData3 ),
				TSymbolClass([{cid:id, className:className}]),
				defineEditTextTag,
				TPlaceObject2(placeObject),
				AbcWriter.createABC(className, 'flash.text.Font'),
				TShowFrame
			]
		}
		// write SWF
		var swfOutput:haxe.io.BytesOutput = new haxe.io.BytesOutput();
		var writer = new Writer(swfOutput);
		writer.write(swfFile);
		var swfBytes:Bytes = swfOutput.getBytes();
		return swfBytes;
	}
	private function getAllRange(tables:Array<Table>):String
	{
		var cmapData=null;
		var glyfData=null;
		for(table in tables)
		{
			switch(table)
			{
				case TGlyf(descriptions): glyfData = descriptions;
				case TCmap(subtables): cmapData = subtables;
				default:
			}
		}
		var glyphIndexArray:Array<GlyphIndex>=new Array();
		for(s in cmapData)
		{
			switch(s)
			{
				case Cmap4(header, array): 
					glyphIndexArray = array;
					break;
				default: 
			}
		}
		var ranges = ["32-32"];
		var range = "";
		var lastCC = 0;
		var addRange = function(charCode, end)
		{
			if(range == "")
			{
				lastCC = charCode;
				range += lastCC;
			}
			else
			{
				if(lastCC+1 == charCode)
				{
					lastCC += 1;
				}
				else
				{
					range += "-"+ lastCC;
					ranges.push(range);
					
					lastCC = charCode;
					range = ""+lastCC;
				}
			}
			if(end)
			{
				range += "-"+ lastCC;
				ranges.push(range);
			}
			
		}
		for(i in 0...glyphIndexArray.length-1)
		{
			if(glyphIndexArray[i]!=null && glyphIndexArray[i].charCode!=0)
			{
				var index = glyphIndexArray[i].index;
				switch(glyfData[index])
				{
					case TGlyphNull: if(i==glyphIndexArray.length-1) addRange(-1, true );
					case TGlyphSimple(header, data): if(data.xCoordinates.length>1) addRange(glyphIndexArray[i].charCode, i==glyphIndexArray.length-1);
					case TGlyphComposite(header, components): addRange(glyphIndexArray[i].charCode,i==glyphIndexArray.length-1);
				}
			}
			if(i==glyphIndexArray.length-2) addRange(-1, true );
		}
		var out = [];
		for(r in ranges)
		{
			var startEnd = r.split("-");
			if(startEnd.length == 4) continue;
			startEnd[0] == startEnd[1]?out.push(startEnd[0]):out.push(r);
		}
		return out.toString();
	}
	var qCpoint:GlyfPath;
	var implicitStart:Bool;
	var implicitEnd:Bool;
	var startPoint:{x:Float, y:Float};
	var implicitCP:{x:Float, y:Float};
	function buildPaths(data:GlyphSimple):Array<GlyfPath>
	{
		var len:Int = data.endPtsOfContours.length;
		var xCoordinates:Array<Float> = new Array();
		for(i in data.xCoordinates)
		{
			xCoordinates.push(i);
		}
		var yCoordinates:Array<Float> = new Array();
		for(i in data.yCoordinates)
		{
			yCoordinates.push(i);
		}
		var cp=0;
		var start=0;
		var end=0;
		var arr:Array<GlyfPath> = new Array();
		for(i in 0...len)
		{
			start = cp;
			end = data.endPtsOfContours[i];
			qCpoint = {type:null, x: xCoordinates[cp], y: yCoordinates[cp], cx:null, cy:null}; 
			if((data.flags[start] & 0x01 != 0) == false)
			{
				implicitStart = true;
				implicitEnd = true;
				implicitCP = {x: xCoordinates[cp], y:yCoordinates[cp]};
			}
			else
			{
				implicitStart = false;
				implicitEnd = false;
				arr.push({type:0, x: xCoordinates[cp], y:yCoordinates[cp], cx:null, cy:null});
			}
			for(j in 0...end-start)
			{
				makePath(cp, cp + 1, arr, data.flags, xCoordinates, yCoordinates, false);
				cp++;
			}
			makePath(end, start, arr, data.flags, xCoordinates, yCoordinates, true);
			cp++;
		}
		return arr;
	}
	private function makePath(p1:Int, p2:Int, arr:Array<GlyfPath>, flags:Array<Int>, xCoordinates:Array<Float>, yCoordinates:Array<Float>, isEndPoint:Bool):Void
	{
		var p1OnCurve:Bool = flags[p1] & 0x01 != 0;
		var p2OnCurve:Bool = flags[p2] & 0x01 != 0;
		if(p1OnCurve && p2OnCurve)
		{
			arr.push({type:1, x:xCoordinates[p2], y:yCoordinates[p2], cx:null, cy:null});
		}
		else if(!p1OnCurve && !p2OnCurve)
		{
			if(implicitStart)
			{
				implicitStart = false;
				arr.push({type:0, x: (xCoordinates[p1] + xCoordinates[p2])/2 , y:(yCoordinates[p1] + yCoordinates[p2])/2, cx:null, cy:null});
				startPoint = {x: (xCoordinates[p1] + xCoordinates[p2])/2 , y:(yCoordinates[p1] + yCoordinates[p2])/2}
			}
			else
			{
				arr.push({type:2, x:(xCoordinates[p1] + xCoordinates[p2])/2, y:(yCoordinates[p1] + yCoordinates[p2])/2, cx: qCpoint.x, cy:qCpoint.y});
			}
			qCpoint = {x: xCoordinates[p2], y: yCoordinates[p2], cx:null, cy:null, type:null};
			if(isEndPoint && implicitEnd)
			{
				implicitEnd = false;
				arr.push({type:2, x:startPoint.x, y:startPoint.y, cx:implicitCP.x, cy:implicitCP.y});
			}
		}
		else if(p1OnCurve && !p2OnCurve)
		{
			qCpoint = {type:null, x: xCoordinates[p2], y: yCoordinates[p2], cx:null, cy:null};
			if(isEndPoint && implicitEnd)
			{
				implicitEnd = false;
				arr.push({type:2, x:startPoint.x, y:startPoint.y, cx:implicitCP.x, cy:implicitCP.y});
			}
		}
		else if(!p1OnCurve && p2OnCurve)
		{
			if(implicitStart)
			{
				implicitStart = false;
				arr.push({type:0, x: xCoordinates[p2], y: yCoordinates[p2], cx: null, cy: null});
				startPoint = {x: xCoordinates[p2], y: yCoordinates[p2]};
			}
			else
			{
				arr.push({type:2, x: xCoordinates[p2], y: yCoordinates[p2], cx: qCpoint.x, cy: qCpoint.y});
			}
			if(isEndPoint && implicitEnd)
			{
				implicitEnd = false;
				arr.push({type:2, x:startPoint.x, y:startPoint.y, cx:implicitCP.x, cy:implicitCP.y});
			}
		}
	}
	private function pairInRange(pair):Bool
	{
		var left = false;
		var right = false;
		for(c in chars)
		{
			
			if(c == pair.left) left = true;
			else if(c == pair.right) right = true;
			if(left && right) return true;
		}
		return false;
	}
	private function init()
	{
		precision = 3;
		zipResources_charClass =
"
package;
// this is character: #C
class Char#0 extends flash.display.Shape
{
	public static inline function commands():Array<Int>{return #commands;}
	public static inline function data():Array<Float>{return #datas;}

#1
	
	public function new(color:Int=0, drawEM:Bool=false, drawBbox:Bool=false, newApi:Bool=false, noFill:Bool=false)
	{
		super();
		noFill?graphics.lineStyle(1, 0):graphics.beginFill(color, 1);
		#if !flash newApi=false; #end
		if(newApi)
		{
			#if flash
			graphics.drawPath(flash.Vector.ofArray(commands()), flash.Vector.ofArray(data()), flash.display.GraphicsPathWinding.EVEN_ODD);
			#end
		}
		else
		{
#2		}
		graphics.endFill();
		
		graphics.lineStyle(1, 0);
		if(drawEM)
		{
			graphics.lineStyle(1, 0xEEEEEE);
			graphics.moveTo(0,(1024-ascent)/2);
			graphics.lineTo(1024, (1024-ascent)/2);
			
			graphics.moveTo(0,1024-(1024-ascent)/2-descent);
			graphics.lineTo(1024, 1024-(1024-ascent)/2-descent);

			graphics.lineStyle(1, 0x0000FF);
			graphics.drawRect(0, 0, 1024, 1024);
			
			graphics.lineStyle(1, 0x00FF00);
			graphics.moveTo(xMin+advanceWidth, 0);
			graphics.lineTo(xMin+advanceWidth, 1024);
		}
		if(drawBbox)
		{
			graphics.lineStyle(1, 0xFF0000);
			graphics.drawRect(xMin, 1024-yMax, xMax-xMin, yMax-yMin);
		}
		
	}
}";
//------------
	zipResources_mainClass =
'
package;
import flash.display.Sprite;
import flash.display.Shape;
#1
class Main extends Sprite
{
	public function new()
	{
		super();
		var charCodes:Array<Int> = #0;
		var scale= 50/1024;
		var vSpace = 10;
		var hSpace = 10;
		var index=0;
		
		var container1 = new Sprite();
		var container2 = new Sprite();
		addChild(container1);
		addChild(container2);
		
		for(i in 0...charCodes.length)
		{
			var glyph1:Shape = Type.createInstance(Type.resolveClass("Char"+charCodes[i]),[0,false,false,true,false]); 
			if(index%16==0) index=0;
			glyph1.x = index*(50+hSpace);
			glyph1.y = Std.int(i/16)*(50+vSpace);
			glyph1.scaleX = glyph1.scaleY=scale;
			container1.addChild(glyph1);
			
			var glyph2:Shape = Type.createInstance(Type.resolveClass("Char"+charCodes[i]),[0,true,true,true,true]);
			glyph2.x = glyph1.x;
			glyph2.y = glyph1.y;
			glyph2.scaleX = glyph2.scaleY=scale;
			container2.addChild(glyph2);
			index++;
		}
		container2.graphics.lineStyle(2,0);
		container2.graphics.drawRoundRect(-20,-20, container2.width+40, container2.height+40, 10);
		container1.graphics.lineStyle(2,0);
		container1.graphics.drawRoundRect(-20,-20, container2.width, container1.height+60, 10);
		container1.x=(1024-container1.width)/2+20;
		container1.y=40;
		container2.x=container1.x;
		container2.y=container1.y+container1.height+20;
	}
	public static function main()
	{
		flash.Lib.current.addChild(new Main());
	}
}
';
//------------
	zipResources_buildFile =
'
-main Main
-swf #0.swf
-swf-header 1024:900:30:FFFFFF
-swf-version 10';
}
}