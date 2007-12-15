/**
 * @author Vladimir Krivosheev
 * @version $Id: PersistenceSession.as 151 2007-11-19 15:41:34Z develar $
 */
package cachegrindVisualizer.callGraph.managers
{
	import cachegrindVisualizer.callGraph.builders.Configuration;
	import cachegrindVisualizer.net.PersistenceSession;
	import cachegrindVisualizer.ui.CallGraph;
	
	import develar.filesystem.FileWrapper;
	import develar.utils.Selector;
	import develar.utils.ObjectUtil;
	import develar.resources.ResourceManager;
	
	import flash.events.Event;
	
	public class ConfigurationManager
	{
		private var fileWrapper:FileWrapper;
		private var callGraph:CallGraph;
		
		private var _configuration:Configuration;
		public function get configuration():Configuration
		{
			return _configuration;
		}
		
		public function ConfigurationManager(callGraph:CallGraph):void
		{
			this.callGraph = callGraph;
			
			if (PersistenceSession.instance.callGraphConfigurationName == null)
			{
				_configuration = new Configuration();				
			}
			else
			{				
				fileWrapper = new FileWrapper('app-storage:/' + PersistenceSession.instance.callGraphConfigurationName);
				_configuration = ObjectUtil.typify(fileWrapper.read(), Configuration);
			}
			
			apply();
		}
		
		public function save():void
		{		
			fileWrapper = new FileWrapper('app-storage:/');
			fileWrapper.file.addEventListener(Event.SELECT, handleSave);
			fileWrapper.file.browseForSave('');
		}
		
		protected function handleSave(event:Event):void
		{
			fileWrapper.contents = configuration;
			PersistenceSession.instance.callGraphConfigurationName = fileWrapper.name;
			fileWrapper = null;
			
			setPanelTitle();
		}
		
		public function load():void
		{
			fileWrapper = new FileWrapper('app-storage:/');
			fileWrapper.file.addEventListener(Event.SELECT, handleLoad);
			fileWrapper.file.browseForOpen('');
		}
		
		protected function handleLoad(event:Event):void
		{
			_configuration = ObjectUtil.typify(fileWrapper.read(), Configuration);
			PersistenceSession.instance.callGraphConfigurationName = fileWrapper.name;
			fileWrapper = null;
			apply();
			
			callGraph.build();
		}
		
		protected function apply():void
		{
			setPanelTitle();
			
			callGraph.title.text = configuration.title;
			Selector.select(callGraph.titleLocation, configuration.titleLocation);
			
			callGraph.minNodeCost.value = configuration.minNodeCost;			
			
			Selector.select(callGraph.labelType, configuration.labelType);
			Selector.select(callGraph.rankDirection, configuration.rankDirection);
			
			callGraph.blackAndWhite.selected = configuration.blackAndWhite;
		}
		
		protected function setPanelTitle():void
		{
			callGraph.panel.title = ResourceManager.instance.getString('CallGraph', 'configuration');
			if (PersistenceSession.instance.callGraphConfigurationName != null)
			{
				callGraph.panel.title += ' (' + PersistenceSession.instance.callGraphConfigurationName + ')';
			}
		}
	}
}