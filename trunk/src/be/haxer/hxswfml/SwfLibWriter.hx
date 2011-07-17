package be.haxer.hxswfml;//be.haxer.hxswfml.SwcWriter;import format.swf.Data;import format.swf.Tools;#if nekoimport neko.Sys;import neko.Lib;import neko.FileSystem;import neko.io.File;#elseif phpimport php.Sys;import php.Lib;import php.FileSystem;import php.io.File;#elseif cppimport cpp.Sys;import cpp.Lib;import cpp.FileSystem;import cpp.io.File;#end/*** * @author Jan J. Flanders*/class SwfLibWriter{	public var library : Hash<Dynamic>;		private var swf:SWF;	private var swfBytes:haxe.io.Bytes;	private var swcClasses : Array<Array<String>>;	private var validElements : Hash<Array<String>>;	private var validChildren : Hash<Array<String>>;	private var bitmapIds : Array<Array<Int>>;	private var currentTag : Xml;	private var id:Int;		public function new()	{		library = new Hash();		swcClasses = new Array();		id=0;		init();	}	private function init():Void	{		validElements = new Hash();		validElements.set('lib', ['version','compressed','width','height','fps','frameCount','backgroundcolor','useDirectBlit','useGPU','hasMetaData','actionscript3','useNetWork']);		validElements.set('bitmapdata', ['file', 'class', 'link']);		validElements.set('bitmap', ['file', 'class', 'link']);		validElements.set('shape', ['file', 'class', 'link']);		validElements.set('sprite', ['file', 'class', 'link']);		validElements.set('movieclip', ['file', 'class', 'link']);		validElements.set('button', ['file', 'class', 'link']);		validElements.set('bytearray', ['file', 'class', 'link']);		validElements.set('font', ['file', 'glyphs', 'class', 'link', 'name']);		validElements.set('sound', ['file', 'class', 'link']);		validElements.set('abc', ['file', 'link', 'isBoot']);		validElements.set('frame', []);		validChildren = new Hash();		validChildren.set('lib', ['bitmapdata', 'bitmap', 'sprite', 'movieclip', 'bytearray', 'font', 'sound', 'abc', 'frame']);	}	public function write(input:String):haxe.io.Bytes	{		bitmapIds = new Array();		var xml : Xml = Xml.parse(input);		var root: Xml = xml.firstElement();		setCurrentElement(root);		var top = readTop();		var tags:Array<SWFTag>=[top.fileAttributes, top.setBackgroundColor];				for(e in root.elements())			if(!validElements.exists(e.nodeName.toLowerCase()))				error('ERROR: Unknown tag: '+ e.nodeName +':'+e.toString);						for(e in root.elements())		{			setCurrentElement(e);			var swftags:Array<SWFTag> = Reflect.field(this, e.nodeName.toLowerCase())();			for (i in 0...swftags.length)				tags.push(swftags[i]);		}		tags.push(TShowFrame);		var swfBytesOutput = new haxe.io.BytesOutput();		var swfWriter = new format.swf.Writer(swfBytesOutput);		swfWriter.write({header:top.header, tags:tags});		swfBytes = swfBytesOutput.getBytes();		return swfBytes;	}	public function getSWF():haxe.io.Bytes	{		return swfBytes;	}	public function getSWC():haxe.io.Bytes	{		return new SwcWriter().write(swcClasses, swfBytes);		//return swfBytes;	}	private function readTop():{header:SWFHeader, fileAttributes:SWFTag, setBackgroundColor:SWFTag}	{		return		{			header:			{				version : getInt('version', 10), 				compressed : getBool('compressed', false), 				width : getInt('width', 800), 				height : getInt('height', 600), 				fps : getInt('fps', 30), 				nframes : getInt('frameCount', 1)			},			fileAttributes:TSandBox(			{				useDirectBlit : getBool('useDirectBlit', false), 				useGPU : getBool('useGPU', false),  				hasMetaData : getBool('hasMetaData', false),  				actionscript3 : getBool('actionscript3', true),  				useNetWork : getBool('useNetwork', false)			}),			setBackgroundColor: TBackgroundColor(getInt('backgroundcolor', 0xffffff))		}	}	private function bitmapdata():Array<SWFTag>	{		var lc = getLinkClass();		var jpegId = ++id;		return [createDefineBitsJPEG(jpegId)].concat(createLinkedSymbol(jpegId, lc.classn, lc.linkn, "flash.display.BitmapData"));	}	private function bitmap():Array<SWFTag>	{		var lc = getLinkClass();		var jpegId = ++id;		return [createDefineBitsJPEG(jpegId)].concat(createLinkedSymbol(jpegId, lc.classn, lc.linkn, "flash.display.Bitmap"));	}	private function sprite():Array<SWFTag>	{		var file = getString('file', "", true);		var lc = getLinkClass();		var extension = file.substr(file.lastIndexOf(".")+1).toLowerCase();		if(extension != "jpg" && extension != "jpeg" && extension != "gif" && extension != "png")			error("Invalid file format, must be gif, jpg, png");		var jpegId = ++id;		var defineBitsJpegTag = createDefineBitsJPEG(jpegId);		var shapeId = ++id;		var defineShapeTag = createDefineShape(shapeId, jpegId);		var mc_tags=[placeobject(shapeId),TShowFrame];		var mcId = ++id;		var out:Array<SWFTag>=[defineBitsJpegTag,defineShapeTag,TClip(mcId, 1, mc_tags)].concat(createLinkedSymbol(mcId, lc.classn, lc.linkn, "flash.display.Sprite"));		return out;	}	private function movieclip():Array<SWFTag>	{		var file = getString('file', "", true);		var lc = getLinkClass();		var extension = file.substr(file.lastIndexOf(".")+1).toLowerCase();		if(extension != "jpg" && extension != "jpeg" && extension != "gif" && extension != "png")			error("Invalid file format, must be gif, jpg, png");		/*		else if(extension == "flv")		{			var fps = getInt('fps', null, false, false);			if(fps==null)fps=12;			var w = getInt('width', null, false, false);			if(w==null)w=320;			var h = getInt('height', null, false, false);			if(h==null)h=240;			var bytes = getBytes(file);			var videoWriter = new VideoWriter();			videoWriter.write(bytes, id, fps, w, h);			return videoWriter.getTags();		}		*/		var out:Array<SWFTag>=new Array();		var jpegId = ++id;		var defineBitsJpegTag = createDefineBitsJPEG(jpegId);		var shapeId = ++id;		var defineShapeTag = createDefineShape(shapeId, jpegId);		var mc_tags=[placeobject(shapeId),TShowFrame];		var mcId = ++id;		var out:Array<SWFTag>= [defineBitsJpegTag,defineShapeTag,TClip(mcId, 1, mc_tags)].concat(createLinkedSymbol(mcId, lc.classn, lc.linkn, "flash.display.MovieClip"));		return out;	}	private function bytearray():Array<SWFTag>	{		var lc = getLinkClass();		var file = getString('file', "", true);		var bytes = getBytes(file);		var binId = ++id;		return [TBinaryData(binId, bytes)].concat(createLinkedSymbol(binId, lc.classn, lc.linkn, "flash.utils.ByteArray"));	}	private function sound():Array<SWFTag>	{		var lc = getLinkClass();		var file = getString('file', "", true);		#if(neko || cpp || php)		checkFileExistence(file);		var mp3FileBytes = File.read(file, true);		#else		var mp3FileBytes = new haxe.io.BytesInput(getBytes(file));		#end		var audioWriter = new AudioWriter();		audioWriter.write(mp3FileBytes, currentTag);		var soundId = ++id;		return [audioWriter.getTag(soundId)].concat(createLinkedSymbol(soundId, lc.classn, lc.linkn, "flash.media.Sound"));			}	private function font():Array<SWFTag>	{		var lc = getLinkClass();		var file = getString('file', "", true);		var fontTag = null;		var extension = file.substr(file.lastIndexOf('.') + 1).toLowerCase();		if(extension == 'swf')		{			var swf = getBytes(file);			var swfBytesInput = new haxe.io.BytesInput(swf);			var swfReader = new format.swf.Reader(swfBytesInput);			var header = swfReader.readHeader();			var tags : Array<SWFTag> = swfReader.readTagList();			swfBytesInput.close();			var _id = ++id;			for (tag in tags)			{				switch (tag)				{					case TFont(id, data) : 						fontTag = TFont(_id, data);						break;					default :				}			}			if(fontTag == null)				error('ERROR: No Font definitions were found inside swf: ' + file + ', TAG: ' + currentTag.toString());		}		else if(extension == 'ttf')		{			var bytes = getBytes(file);			var ranges = getString('glyphs', "32-126", false);			var fontWriter = new FontWriter();			fontWriter.write(bytes, ranges, 'swf');			fontTag = fontWriter.getTag(++id);		}		else if(extension =="otf")		{			var bytes = getBytes(file);			var fontWriter = new FontWriter();			var name = getString('name', "", true);			fontTag = fontWriter.writeOTF(++id, name, bytes);			if(fontTag==null)				error('ERROR: Not a valid OTTO OTF font file: ' + file + ', TAG: ' + currentTag.toString());		}		else		{			error('ERROR: Not a valid font file:' + file + ', TAG: ' + currentTag.toString() + 'Valid file types are: .swf and .ttf');		}		return [fontTag].concat(createLinkedSymbol(id, lc.classn, lc.linkn, "flash.text.Font"));	}	private function button():Array<SWFTag>	{		id++;		var lc = getLinkClass();		var file = getString('file', "", true);		var bytes = getBytes(file);		var imageWriter = new ImageWriter();		imageWriter.write(bytes, file, currentTag);		var bitmapTag = imageWriter.getTag(id);		var width = imageWriter.width * 20;		var height = imageWriter.height * 20;		var shapeWithStyle = 		{			fillStyles:[FSBitmap(id, {scale : {x : 20.0, y : 20.0}, rotate : {rs0 : 0.0, rs1 : 0.0}, translate : {x : 0, y : 0}}, false, false)],			lineStyles:[], 			shapeRecords:[SHRChange({moveTo:{dx:width,dy:0},fillStyle0:{idx:1},fillStyle1:null,lineStyle:null,newStyles:null}),SHREdge(0,height),SHREdge(-width,0),SHREdge(0,-height),SHREdge(width,0),SHREnd]		}		id++;		var shapeTag = TShape(id, SHDShape1({left : 0, right : width, top : 0,  bottom : height}, shapeWithStyle));		var buttonRecords : Array<ButtonRecord> =[{hit : true, down : true, over : true, up : true, id : id, depth : 1, matrix : {scale:null, rotate:null, translate:{x:0, y:0}}}];		id++;		var buttonTag = TDefineButton2(id, buttonRecords);		return [bitmapTag, shapeTag,buttonTag].concat(createLinkedSymbol(id, lc.classn, lc.linkn, "flash.display.SimpleButton"));	}	private function abc():Array<SWFTag>	{		//var lc = getLinkClass();		var linkn = getString('link', "", false);		var file = getString('file', "", true);		var isBoot = getBool('isBoot', false);		var abcTag = null;		var extension = file.substr(file.lastIndexOf('.') + 1).toLowerCase();		if(extension == 'swf')		{			var swf = getBytes(file);			var swfBytesInput = new haxe.io.BytesInput(swf);			var swfReader = new format.swf.Reader(swfBytesInput);			var header = swfReader.readHeader();			var tags : Array<SWFTag> = swfReader.readTagList();			swfBytesInput.close();			for (tag in tags)			{				switch (tag)				{					default :					case TActionScript3(data, context): 						abcTag = tag;						break;				}			}			if(abcTag == null)				error('ERROR: No script was found inside swf: ' + file + ', TAG: ' + currentTag.toString());			if(isBoot && linkn=="")				for (tag in tags)					switch (tag)					{						default :						case TSymbolClass(symbols):								for(s in symbols)									if( s.cid==0 )										linkn = s.className;					}		}		return [abcTag].concat(createLinkedSymbol(0, "", linkn));	}	private function frame():Array<SWFTag>	{		return [TShowFrame];	}	private function createDefineBitsJPEG(id):SWFTag	{		var file = getString('file', "", true);		var bytes = getBytes(file);		var imageWriter = new ImageWriter();		imageWriter.write(bytes, file, currentTag);		bitmapIds[id] = [imageWriter.width, imageWriter.height];		return imageWriter.getTag(id);	}	private function createDefineShape(id, bitmapId):SWFTag	{		var width = bitmapIds[bitmapId][0] * 20;		var height = bitmapIds[bitmapId][1] * 20;		var shapeWithStyle = 		{			fillStyles:[FSBitmap(bitmapId, {scale : {x : 20.0, y : 20.0}, rotate : {rs0 : 0.0, rs1 : 0.0}, translate : {x : 0, y : 0}}, false, false)],			lineStyles:[], 			shapeRecords:[			SHRChange({moveTo:{dx:width,dy:0},			fillStyle0:{idx:1},			fillStyle1:null,			lineStyle:null,			newStyles:null}),			SHREdge(0,height),			SHREdge(-width,0),			SHREdge(0,-height),			SHREdge(width,0),			SHREnd]		}		return TShape(id, SHDShape1({left:0, right : width, top:0,  bottom : height}, shapeWithStyle));	}	private function placeobject(id):SWFTag	{		var placeObject : PlaceObject = new PlaceObject();		placeObject.depth = 1;		placeObject.move = false;		placeObject.cid = id;		placeObject.matrix = {scale:null,rotate:null,translate:{x:0,y:0}};		placeObject.color = null;		placeObject.ratio = null;		placeObject.instanceName = null;		placeObject.clipDepth = null;		placeObject.events = null;		placeObject.blendMode = null;		placeObject.bitmapCache = false;		placeObject.className = null;		placeObject.hasImage = false;		placeObject.filters = null;		return TPlaceObject2(placeObject);	}	private function getContent(file:String):String	{		checkFileExistence(file);		#if (neko || cpp ||php)			return File.getContent(file);		#elseif air			var f = new flash.filesystem.File();			f = f.resolvePath(file);			var fileStream = new flash.filesystem.FileStream();			fileStream.open(f, flash.filesystem.FileMode.READ);			var str = fileStream.readMultiByte(f.size, flash.filesystem.File.systemCharset);			fileStream.close();			return str;		#else			return Std.string(library.get(file));		#end	}	private function getBytes(file:String):haxe.io.Bytes	{		checkFileExistence(file);		#if (neko || cpp ||php)			return File.getBytes(file);		#elseif air			var f = new flash.filesystem.File();			f = f.resolvePath(file);			var fileStream = new flash.filesystem.FileStream();			fileStream.open(f, flash.filesystem.FileMode.READ);			var byteArray : flash.utils.ByteArray = new flash.utils.ByteArray();			fileStream.readBytes(byteArray);			fileStream.close();			return haxe.io.Bytes.ofData(byteArray);		#else			return haxe.io.Bytes.ofData(library.get(file));		#end	}	private function getInt(att : String, defaultValue, ?required : Bool = false, ?uniqueId : Bool = false, ?targetId : Bool = false)	{		if(currentTag.exists(att))			if(Math.isNaN(Std.parseInt(currentTag.get(att))))				error('ERROR: attribute ' + att + ' must be an integer: ' + currentTag.toString());		if(required)			if(!currentTag.exists(att))				error('ERROR: Required attribute ' + att + ' is missing in tag: ' + currentTag.toString());		return currentTag.exists(att)?  Std.parseInt(currentTag.get(att)) : defaultValue;	}	private function getBool(att : String, defaultValue : Null<Bool>, ?required : Bool = false):Null<Bool>	{		if(required)			if(!currentTag.exists(att))				error('ERROR: Required attribute ' + att + ' is missing in tag: ' + currentTag);		return currentTag.exists(att)? (currentTag.get(att) == 'true'? true : false) : defaultValue;	}	private function getFloat(att : String, defaultValue : Null<Float>, ?required : Bool = false): Null<Float>	{		if(currentTag.exists(att))			if(Math.isNaN(Std.parseFloat(currentTag.get(att))))				error('ERROR: attribute ' + att + ' must be a number: ' + currentTag.toString());		if(required)			if(!currentTag.exists(att))				error('ERROR: Required attribute ' + att + ' is missing in tag: ' + currentTag.toString());		return currentTag.exists(att)? Std.parseFloat(currentTag.get(att)) : defaultValue;	}	private function getString(att : String, defaultValue : String, ?required : Bool = false): String	{		if(required)			if(!currentTag.exists(att))				error('ERROR: Required attribute ' + att + ' is missing in tag: ' + currentTag.toString());		return currentTag.exists(att)? currentTag.get(att) : defaultValue;	}	private function parseInt32(s:String):haxe.Int32	{		var f=Std.parseFloat(s);		if(f<-1073741824)			return haxe.Int32.add(haxe.Int32.ofInt(-1073741824),haxe.Int32.ofInt(Std.int(f+1073741824)));		if(f>1073741823)			return haxe.Int32.add(haxe.Int32.ofInt(1073741823),haxe.Int32.ofInt(Std.int(f-1073741823)));		return haxe.Int32.ofInt(Std.int(f));	}	private function checkFileExistence(file : String) : Void	{		#if neko		if(!neko.FileSystem.exists(file))		{			error('ERROR: File: ' + file + ' could not be found at the given location. TAG: ' + currentTag.toString());		}		#elseif cpp		if(!cpp.FileSystem.exists(file))		{			error('ERROR: File: ' + file + ' could not be found at the given location. TAG: ' + currentTag.toString());		}		#elseif php		if(!php.FileSystem.exists(file))		{			error('ERROR: File: ' + file + ' could not be found at the given location. TAG: ' + currentTag.toString());		}		#elseif air			var f = new flash.filesystem.File(file);			if(!f.exists)			{				error('ERROR: File: ' + file + ' could not be found at the given location. TAG: ' + currentTag.toString());			}		#else			if(library.get(file) == null)			{				error('ERROR: File: ' + file + ' could not be found in the library. TAG: ' + currentTag.toString());			}		#end	}	private function setCurrentElement(tag:Xml) : Void	{		currentTag = tag;		if(!validElements.exists(currentTag.nodeName.toLowerCase()))			error('ERROR: Unknown tag: '+ currentTag.nodeName);		for(a in currentTag.attributes())		{			if(!isValidAttribute(a))			{				if(currentTag.nodeName.toLowerCase()!="swf")				error('ERROR: Unknown attribute: ' + a + '. Valid attributes are: ' + validElements.get(currentTag.nodeName.toLowerCase()).toString() +'. TAG: ' + currentTag.toString());			}		}	}	private function isValidAttribute(a : String) : Bool	{		var validAttributes = validElements.get(currentTag.nodeName.toLowerCase());		for(i in validAttributes)		{			if(a == i)				return true;		}		return false;	}	private function createLinkedSymbol(id, classn, linkn, ?basen):Array<SWFTag>	{		swcClasses.push([linkn, basen]);		return (classn == linkn)?[AbcWriter.createABC(classn, basen), TSymbolClass([{cid:id, className:linkn}])]:[TSymbolClass([{cid:id, className:linkn}])];	}	private function getLinkClass():{linkn:String, classn:String}	{		var classn = getString('class', "", false);		var linkn = classn!="" ? classn : getString('link', "", false);		if(linkn=="")			error("ERROR: You must provide a link or a class attribute. " + currentTag.toString());		return {linkn:linkn, classn:classn};	}	private function error(msg : String):Void	{			throw msg;	}}