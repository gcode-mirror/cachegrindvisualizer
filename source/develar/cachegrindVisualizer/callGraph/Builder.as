package develar.cachegrindVisualizer.callGraph
{
	import flash.filesystem.File;
	
	import mx.resources.ResourceBundle;
	
	import develar.filesystem.FileWrapper;
	
	import develar.cachegrindVisualizer.Item;
	
	public class Builder
	{
		protected const PERCENTAGE_FRACTION_DIGITS:uint = 2;
		protected const TIME_FRACTION_DIGITS:uint = 2;
		
		protected const LABEL_TYPE_PERCENTAGE:uint = 0;
		protected const LABEL_TYPE_TIME:uint = 1;
		protected const LABEL_TYPE_PERCENTAGE_AND_TIME:uint = 2;
		protected const LABEL_TYPE_TIME_AND_PERCENTAGE:uint = 3;
		
		protected var graph:String;
		protected var nodes:Object;
		
		protected var _minPercentage:uint = 1;
		public function set minPercentage(value:uint):void
		{
			_minPercentage = value;
		}
		
		protected var _labelType:uint = 2;
		public function set labelType(value:uint):void
		{
			_labelType = value;
		}
		
		public function build(data:Item, file:File):void
		{
			nodes = {main: new Node()};
			setNode(data);
			
			graph = "digraph {\n";
			
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
					graph += '"' + parent.name + '" -> "' + item.name + '" [label="' + item.inclusivePercentage.toFixed(PERCENTAGE_FRACTION_DIGITS) + ' %"];\n';
					
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
			if (_labelType > 0)
			{
				nodes[item.name].time += item.inclusiveTime;
			}
			if (_labelType != LABEL_TYPE_TIME)
			{
				nodes[item.name].percentage += item.inclusivePercentage;
			}
		}
		
		private function configurateNodes():void
		{
			var timeUnit:String = ResourceBundle.getResourceBundle('CachegrindVisualizer').getString('timeUnit');
			
			for (var name:String in nodes)
			{
				var label:String = name + '\\n';
				switch (_labelType)
				{
					case LABEL_TYPE_PERCENTAGE:
					{
						label += nodes[name].percentage.toFixed(PERCENTAGE_FRACTION_DIGITS) + ' %';
					}
					break;
					
					case LABEL_TYPE_TIME:
					{
						label += nodes[name].time.toFixed(TIME_FRACTION_DIGITS) + ' ' + timeUnit;
					}
					break;
					
					case LABEL_TYPE_PERCENTAGE_AND_TIME:
					{
						label += nodes[name].percentage.toFixed(PERCENTAGE_FRACTION_DIGITS) + ' % (' + nodes[name].time + ' ' + timeUnit + ')';
					}
					break;
					
					case LABEL_TYPE_TIME_AND_PERCENTAGE:
					{
						label += nodes[name].time + ' ' + timeUnit + ' (' + nodes[name].percentage.toFixed(PERCENTAGE_FRACTION_DIGITS) + ' %)';
					}
					break;
					
					default:
					{
						throw new Error('Unknown label type');
					}	
					break;				
				}
				
				graph += '"' + name + '" [label="' + label + '"];\n';
			}
		}
	}
}