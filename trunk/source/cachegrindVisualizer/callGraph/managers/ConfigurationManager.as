/**
 * @author Vladimir Krivosheev
 * @version $Id: PersistenceSession.as 151 2007-11-19 15:41:34Z develar $
 */
package develar.cachegrindVisualizer.callGraph.managers
{
	import flash.events.Event;
	import flash.net.URLRequest;
	
	import mx.core.Application;
	
	import develar.filesystem.FileWrapper;
	import develar.utils.Selector;
	
	import develar.cachegrindVisualizer.ui.CallGraph;
	import develar.cachegrindVisualizer.callGraph.builders.Builder;
	import develar.cachegrindVisualizer.callGraph.builders.Label;
	import develar.cachegrindVisualizer.net.PersistenceSession;
	
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
			
			if (PersistenceSession.instance.callGraphConfigurationName == null)
			{
				PersistenceSession.instance.callGraphConfigurationName = 'default';
			}
			
			fileWrapper = new FileWrapper('app-storage:/' + PersistenceSession.instance.callGraphConfigurationName);
			if (fileWrapper.file.exists)
			{
				_object = fileWrapper.read();
			}
			else
			{
				_object = {minNodeCost: 1, labelType: Label.TYPE_PERCENTAGE_AND_TIME, rankDirection: Builder.RANK_DIRECTION_TB, blackAndWhite: false};
				fileWrapper.contents = _object;
			}
			
			apply();
		}
		
		public function save():void
		{
			object.minNodeCost = callGraph.minNodeCost.value;
			object.labelType = callGraph.labelType.selectedItem.data;
			object.rankDirection = callGraph.rankDirection.selectedItem.data;
			object.blackAndWhite = callGraph.blackAndWhite.selected;
		
			fileWrapper = new FileWrapper('app-storage:/');
			fileWrapper.file.addEventListener(Event.SELECT, handleSave);
			fileWrapper.file.browseForSave('');
		}
		
		protected function handleSave(event:Event):void
		{
			fileWrapper.contents = _object;
		}
		
		public function load():void
		{
			fileWrapper = new FileWrapper('app-storage:/');
			fileWrapper.file.addEventListener(Event.SELECT, handleLoad);
			fileWrapper.file.browseForOpen('');
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
			callGraph.blackAndWhite.selected = object.blackAndWhite;
			
			callGraph.builder.minNodeCost = object.minNodeCost;
			callGraph.builder.label.type = object.labelType;
			callGraph.builder.rankDirection = object.rankDirection;
			callGraph.builder.blackAndWhite = object.blackAndWhite;
		}
	}
}