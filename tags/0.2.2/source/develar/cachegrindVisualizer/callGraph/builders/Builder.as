package develar.cachegrindVisualizer.callGraph.builders
{	
	import develar.filesystem.FileWrapper;
	
	import develar.cachegrindVisualizer.Item;
	import develar.cachegrindVisualizer.callGraph.Node;
	
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
		
		protected var color:Color = new Color();
		
		protected var _label:Label = new Label();
		public function get label():Label
		{
			return _label;
		}
		
		protected var _minNodeCost:Number = 1;
		public function set minNodeCost(value:Number):void
		{
			_minNodeCost = value;
		}
		
		protected var _rankDirection:uint = 0;
		public function set rankDirection(value:uint):void
		{
			_rankDirection = value;
		}		
		
		protected var _blackAndWhite:Boolean = false;
		public function set blackAndWhite(value:Boolean):void
		{
			_blackAndWhite = value;
		}
		
		public function build(item:Item, fileWrapper:FileWrapper):void
		{
			onePercentage = item.inclusiveTime / 100;
			item.percentage = item.time / onePercentage;
			item.inclusivePercentage = 100;
			
			nodes = {};
			setNode(item);
			
			graph = 'digraph { rankdir="' + rankDirections[_rankDirection] + '";\nedge [labelfontsize=12];\n';		
			if (!_blackAndWhite)
			{
				graph += 'node [style=filled];\n';
			}			
			graph += '\n';			
				
			buildEdge(item, item.time > 0 ? label.arrow(item, onePercentage) : '');
			graph += '\n';
			buildNodes();			
			graph += '}';
			
			fileWrapper.contents = graph;
			nodes = null;
			graph = null;
		}
		
		protected function buildEdge(parent:Item, parentArrowLabel:String):void
		{			
			for each (var item:Item in parent.children)
			{
				item.percentage = item.time / onePercentage;
				item.inclusivePercentage = item.inclusiveTime / onePercentage;				
				
				if (item.inclusivePercentage >= _minNodeCost)
				{
					graph += '"' + parent.name + '" -> "' + item.name + '" [label="' + label.edge(item) + '"';
					
					if (parentArrowLabel != '')
					{						
						graph += ', taillabel="' + parentArrowLabel + '"';
					}
										
					var itemArrowLabel:String = '';
					// если элемент не имеет детей, то смысла в метке острия стрелки нет - она всегда будет равна метке ребра
					if (item.children != null && item.time > 0)
					{
						itemArrowLabel = label.arrow(item, onePercentage);
						graph += ', headlabel="' + itemArrowLabel + '"';
					}
					
					if (!_blackAndWhite)
					{
						graph += ', color="' + color.edge(item) + '"';
					}
					
					graph += '];\n';
					
					if (item.children != null)
					{						
						buildEdge(item, itemArrowLabel);
					}
					
					setNode(item);
				}
			}
		}
		
		protected function setNode(item:Item):void
		{
			if (!(item.name in nodes))
			{
				nodes[item.name] = new Node();
			}
			
			var node:Node = nodes[item.name];
			node.percentage += item.percentage;
			if (_label.type > 0)
			{
				node.inclusiveTime += item.inclusiveTime;
			}
			if (_label.type != Label.TYPE_TIME)
			{
				node.inclusivePercentage += item.inclusivePercentage;
			}
		}
		
		protected function buildNodes():void
		{
			for (var name:String in nodes)
			{				
				graph += '"' + name + '" [label="' + label.node(name, nodes[name]) + '"';
				if (!_blackAndWhite)
				{
					graph += ', color="' + color.node(nodes[name]) + '"';
				}
				graph += '];\n';
			}
		}
	}
}