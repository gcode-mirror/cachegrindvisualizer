package develar.cachegrindVisualizer.callGraph
{	
	import develar.filesystem.FileWrapper;
	
	import develar.cachegrindVisualizer.Item;
	
	public class Builder
	{
		public static const RANK_DIRECTION_TB:uint = 0;
		public static const RANK_DIRECTION_LR:uint = 1;
		public static const RANK_DIRECTION_BT:uint = 2;
		public static const RANK_DIRECTION_RL:uint = 3;
		
		protected var rankDirections:Array = ['TB', 'LR', 'BT', 'RL'];
		
		protected var graph:String;
		protected var nodes:Object;
		
		protected var onePercentage:Number;
		
		protected var _labelCreator:LabelCreator = new LabelCreator();
		public function get labelCreator():LabelCreator
		{
			return _labelCreator;
		}
		
		protected var _minNodeCost:uint = 1;
		public function set minNodeCost(value:uint):void
		{
			_minNodeCost = value;
		}
		
		protected var _rankDirection:String = 'TB';
		public function set rankDirection(value:String):void
		{
			_rankDirection = value;
		}		
		
		public function build(data:Item, fileWrapper:FileWrapper):void
		{
			onePercentage = data.inclusiveTime / 100;
			data.inclusivePercentage = 100;
			
			nodes = {};
			nodes[data.name] = new Node();
			setNode(data);
			
			graph = 'digraph { rankdir="' + rankDirections[_rankDirection] + '";edge [labelfontsize=12]; \n';			
			createEdge(data);
			configurateNodes();			
			graph += '}';
			
			fileWrapper.contents = graph;
			nodes = null;
			graph = null;
		}
		
		private function createEdge(parent:Item):void
		{			
			for each (var item:Item in parent.children)
			{
				item.inclusivePercentage = item.inclusiveTime / onePercentage;
				if (item.inclusivePercentage >= _minNodeCost)
				{
					graph += '"' + parent.name + '" -> "' + item.name + '" [label="' + labelCreator.arrow(item) + '"';

					if (parent.time > 0)
					{
						graph += ', taillabel="' + labelCreator.arrowTail(parent, onePercentage) + '"';
					}
					// если элемент не имеет детей, то смысла в метке острия стрелки нет - она всегда будет равна метке стрелки
					if (item.children != null && item.time > 0)
					{
						graph += ', headlabel="' + labelCreator.arrowTail(item, onePercentage) + '"';
					}
					
					graph += '];\n';
					
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
				if (item.name == 'Page_types_cms->setData')
				{
					trace(nodes[item.name].percentage, item.inclusivePercentage);
				}
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