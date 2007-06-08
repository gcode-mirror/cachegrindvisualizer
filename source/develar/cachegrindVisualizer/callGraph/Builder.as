package develar.cachegrindVisualizer.callGraph
{
	import flash.filesystem.File;
	
	import develar.filesystem.FileWrapper;
	
	import develar.cachegrindVisualizer.Item;
	
	public class Builder
	{
		protected var graph:String;
		protected var nodes:Object;
		
		protected var _labelCreator:LabelCreator = new LabelCreator();
		public function get labelCreator():LabelCreator
		{
			return _labelCreator;
		}
		
		protected var _minPercentage:uint = 1;
		public function set minPercentage(value:uint):void
		{
			_minPercentage = value;
		}
		
		protected var _rankDirection:String = 'TB';
		public function set rankDirection(value:String):void
		{
			_rankDirection = value;
		}		
		
		public function build(data:Item, file:File):void
		{
			nodes = {main: new Node()};
			setNode(data);
			
			graph = 'digraph { rankdir="' + _rankDirection + '" \n';
			
			createEdge(data);
			configurateNodes();
			
			graph += '}';
			
			var fileWrapper:FileWrapper = new FileWrapper(file);
			fileWrapper.contents = graph;
			graph = null;
		}
		
		private function createEdge(parent:Item):void
		{			
			for each (var item:Item in parent.children)
			{
				if (item.inclusivePercentage > _minPercentage)
				{
					graph += '"' + parent.name + '" -> "' + item.name + '" [label="' + labelCreator.arrow(item) + '"];\n';
					
					if (item.children != null)
					{						
						createEdge(item);
					}
					
					if (!(item.name in nodes))
					{
						nodes[item.name] = new Node();
					}
					setNode(item);
				}
			}
		}
		
		private function setNode(item:Item):void
		{
			if (_labelCreator.type > 0)
			{
				nodes[item.name].time += item.inclusiveTime;
			}
			if (_labelCreator.type != LabelCreator.TYPE_TIME)
			{
				nodes[item.name].percentage += item.inclusivePercentage;
			}
		}
		
		private function configurateNodes():void
		{
			for (var name:String in nodes)
			{
				graph += '"' + name + '" [label="' + labelCreator.node(name, nodes[name]) + '"];\n';
			}
		}
	}
}