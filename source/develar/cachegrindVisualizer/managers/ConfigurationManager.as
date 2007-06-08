package develar.cachegrindVisualizer.managers
{
	import flash.events.Event;
	import flash.net.URLRequest;
	
	import develar.filesystem.FileWrapper;
	
	public class ConfigurationManager
	{
		protected var fileWrapper:FileWrapper;
		protected var object:Object;
		
		public function save(object:Object):void
		{
			this.object = object;
			fileWrapper = new FileWrapper('app-storage:/');
			fileWrapper.file.addEventListener(Event.SELECT, handleSave);
			fileWrapper.file.download(new URLRequest('http://hack'), ' ');
		}
		
		protected function handleSave(event:Event):void
		{
			fileWrapper.file.cancel();
			fileWrapper.contents = object;
		}
		
		public function load():void
		{
			fileWrapper = new FileWrapper('app-storage:/');
			fileWrapper.file.addEventListener(Event.SELECT, handleLoad);
			fileWrapper.file.browse();
		}
		
		protected function handleLoad(event:Event):Object
		{
			return fileWrapper.read();
		}
	}
}