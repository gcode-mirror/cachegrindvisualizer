package develar.cachegrindVisualizer.callGraph.managers
{
	import flash.events.Event;
	import flash.net.URLRequest;
	
	import mx.core.Application;
	
	import develar.filesystem.FileWrapper;
	import develar.utils.Selector;
	
	import develar.cachegrindVisualizer.ui.CallGraph;
	import develar.cachegrindVisualizer.callGraph.Builder;
	import develar.cachegrindVisualizer.callGraph.LabelCreator;
	
	public class ConfigurationManager
	{
		protected var fileWrapper:FileWrapper;
		protected var callGraph:CallGraph;
		
		protected var _object:Object;
		public function get object():Object
		{
			return _object;
		}
		
		public function ConfigurationManager(call_graph:CallGraph):void
		{
			callGraph = call_graph;
			
			if (!('callGraphConfigurationName' in CachegrindVisualizer(Application.application).persistenceSession.data))
			{
				CachegrindVisualizer(Application.application).persistenceSession.data.callGraphConfigurationName = 'default';
			}
			
			fileWrapper = new FileWrapper('app-storage:/' + CachegrindVisualizer(Application.application).persistenceSession.data.callGraphConfigurationName);
			if (fileWrapper.file.exists)
			{
				_object = fileWrapper.read();
			}
			else
			{
				_object = {minNodeCost: 1, labelType: LabelCreator.TYPE_PERCENTAGE_AND_TIME, rankDirection: Builder.RANK_DIRECTION_TB};
				fileWrapper.contents = _object;
			}
			
			apply();
		}
		
		public function save():void
		{
			object.minNodeCost = callGraph.minNodeCost.value;
			object.labelType = callGraph.labelType.selectedItem.data;
			object.rankDirection = callGraph.rankDirection.selectedItem.data;
		
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
			apply();
			callGraph.build();
		}
		
		protected function apply():void
		{
			callGraph.minNodeCost.value = object.minNodeCost;
			Selector.select(callGraph.labelType, object.labelType);
			Selector.select(callGraph.rankDirection, object.rankDirection);
			
			callGraph.builder.minNodeCost = object.minNodeCost;
			callGraph.builder.labelCreator.type = object.labelType;
			callGraph.builder.rankDirection = object.rankDirection;
		}
	}
}