﻿package 
{
	import flash.display.*;
	import flash.events.*;
	import flash.net.*;
	import flash.text.*;
	import flash.utils.*;
	import be.haxer.hxswfml.SwfWriter;

	public class Main extends Sprite
	{
		private var xml:String;
		private var swf:ByteArray;
		private var saveBtn:Sprite;
		private var fr:FileReference;
		private var tf:TextField;

		public function Main()
		{
			haxe.initSwc(new MovieClip());
			
			//textfield
			tf = new TextField();
			tf.width=tf.height=400;
			tf.x=tf.y=100;
			tf.border=true;
			addChild(tf);
			
			//saveBtn
			saveBtn=new Sprite();
			saveBtn.graphics.lineStyle(2,0);
			saveBtn.graphics.beginFill(0xff0000,1);
			saveBtn.graphics.drawRect(0,0,100,20);
			var tfB:TextField=new TextField();
			tfB.text = 'SAVE SWF';
			tfB.autoSize= TextFieldAutoSize.LEFT
			tfB.x = (saveBtn.width-tfB.width)/2;
			tfB.y = (saveBtn.height-tfB.height)/2;
			saveBtn.addChild(tfB);
			saveBtn.mouseChildren = false;
			saveBtn.buttonMode = true;
			saveBtn.visible = false;
			saveBtn.addEventListener(MouseEvent.CLICK, onSaveBtnClick);
			addChild(saveBtn);

			//FileReference
			fr = new FileReference();

			//xml loader
			var xmlLoader = new URLLoader();
			xmlLoader.dataFormat = URLLoaderDataFormat.TEXT;
			xmlLoader.addEventListener(Event.COMPLETE, onXmlLoaderComplete);
			xmlLoader.load(new URLRequest('index.xml'));
		}
		private function onXmlLoaderComplete(event:Event):void
		{
			xml = event.target.data;
			tf.text = xml;
			var swfWriter = new SwfWriter();
			
			swfWriter.write(xml,'output.swf');//'output.swc'
			var bytes = swfWriter.getSWF();
			swf = bytes.getData();
			saveBtn.visible = true;
		}
		private function onSaveBtnClick(event:MouseEvent):void
		{
			fr.save(swf,'output.swf');//'output.swc'
		}
	}
}