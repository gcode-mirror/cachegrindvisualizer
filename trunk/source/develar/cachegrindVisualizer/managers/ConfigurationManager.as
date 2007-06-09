package develar.cachegrindVisualizer.managers
{
	import flash.events.Event;
	import flash.net.URLRequest;
	
	import mx.core.Application;
	
	import develar.filesystem.FileWrapper;
	
	public class ConfigurationManager
	{
		protected var fileWrapper:FileWrapper;
		
		protected var _object:Object;
		public function get object():Object
		{
			return _object;
		}
		
		public function ConfigurationManager():void
		{
			if (!('callGraphConfigurationName' in CachegrindVisualizer(Application.application).persistenceSession.data))
			{
				CachegrindVisualizer(Application.application).persistenceSession.data.callGraphConfigurationName = 'default';
			}
			
			fileWrapper = new FileWrapper('app-storage:/' + CachegrindVisualizer(Application.application).persistenceSession.data.callGraphConfigurationName);
			
			_object = fileWrapper.read();
		}
		
		public function save():void
		{
			fileWrapper = new FileWrapper('app-storage:/');
			fileWrapper.file.addEventListener(Event.SELECT, handleSave);
			fileWrapper.file.download(new URLRequest('http://hack'), ' ');
		}
		
		protected function handleSave(event:Event):void
		{
			fileWrapper.file.cancel();
			fileWrapper.contents = _object;
		}
		
		public function load():void
		{
			fileWrapper = new FileWrapper('app-storage:/');
			fileWrapper.file.addEventListener(Event.SELECT, handleLoad);
			fileWrapper.file.browse();
		}
		
		protected function handleLoad(event:Event):void
		{
			_object = fileWrapper.read();
		}
	}
}