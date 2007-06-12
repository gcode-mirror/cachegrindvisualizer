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
		
		public function build(item:Item, fileWrapper:FileWrapper):void
		{
			onePercentage = item.inclusiveTime / 100;
			item.percentage = item.time / onePercentage;
			item.inclusivePercentage = 100;
			
			nodes = {};
			nodes[item.name] = new Node();
			setNode(item);
			
			graph = 'digraph { rankdir="' + rankDirections[_rankDirection] + '"; edge [labelfontsize=12]; node [style=filled]; \n';			
			createEdge(item);
			graph += '\n';
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
				item.percentage = item.time / onePercentage;
				item.inclusivePercentage = item.inclusiveTime / onePercentage;				
				
				if (item.inclusivePercentage >= _minNodeCost)
				{
					graph += '"' + parent.name + '" -> "' + item.name + '" [label="' + labelCreator.arrow(item) + '"';

					if (parent.time > 0)
					{
						graph += ', taillabel="' + labelCreator.arrowHeadOrTail(parent, onePercentage) + '"';
					}
					// если элемент не имеет детей, то смысла в метке острия стрелки нет - она всегда будет равна метке стрелки
					if (item.children != null && item.time > 0)
					{
						graph += ', headlabel="' + labelCreator.arrowHeadOrTail(item, onePercentage) + '"';
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
			var node:Node = nodes[item.name];
			node.percentage += item.percentage;
			if (_labelCreator.type > 0)
			{
				node.inclusiveTime += item.inclusiveTime;
			}
			if (_labelCreator.type != LabelCreator.TYPE_TIME)
			{
				node.inclusivePercentage += item.inclusivePercentage;
			}
		}
		
		private function configurateNodes():void
		{
			for (var name:String in nodes)
			{
				var node:Node = nodes[name];
				
				var colorValue:Number = node.percentage / 100;
				
				var hue:Number = 0.6 + colorValue;
				if (hue > 1)
				{
					hue = 1;
				}
				
				var saturation:Number = 0.1 + colorValue;
				if (saturation > 1)
				{
					saturation = 1;
				}
				
				var brightness:Number = /*colorValue + 0.99*/1;
				if (brightness > 1)
				{
					brightness = 1;
				}
				
				graph += '"' + name + '" [label="' + labelCreator.node(name, node) + '", color="' + hue + ' ' + saturation + ' ' + brightness + '"];\n';
			}
		}
	}
}