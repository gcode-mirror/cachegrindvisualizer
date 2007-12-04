package develar.cachegrindVisualizer.callGraph.builders
{
	import mx.formatters.NumberBaseRoundType;
	import mx.resources.ResourceManager;
	
	import develar.formatters.NumberFormatter;
	
	public class Label
	{
		public static const TYPE_PERCENTAGE:uint = 0;
		public static const TYPE_TIME:uint = 1;
		public static const TYPE_PERCENTAGE_AND_TIME:uint = 2;
		public static const TYPE_TIME_AND_PERCENTAGE:uint = 3;
		
		protected const PERCENTAGE_PRECISION:uint = 2;
		
		protected var percentageFormatter:NumberFormatter = new NumberFormatter();
		protected var timeFormatter:NumberFormatter = new NumberFormatter();
		
		protected var _type:uint = 2;
		public function get type():uint
		{
			return _type;
		}
		public function set type(value:uint):void
		{
			_type = value;
		}
		
		public function Label():void
		{
			timeFormatter.precision = -1;
			
			percentageFormatter.precision = PERCENTAGE_PRECISION;
			percentageFormatter.rounding = NumberBaseRoundType.NEAREST;
		}
		
		public function edge(edge:Edge):String
		{			
			return build(edge.inclusivePercentage, edge.inclusiveTime);
		}
		
		public function arrow(edge:Edge, onePercentage:Number):String
		{			
			return build(edge.time / onePercentage, edge.time);
		}
		
		public function node(node:Node):String
		{
			return build(node.inclusivePercentage, node.inclusiveTime, node.name);
		}
		
		protected function build(percentage:Number, time:uint, nodeName:String = null):String
		{
			var label:String = '';		
			if (nodeName != null)
			{
				// Graphviz воспринимает \ как управляющий символ, поэтому его необходимо экранировать
				label = nodeName.replace(/\\/g, '\\\\') + '\\n';
			}
			
			switch (_type)
			{
				case TYPE_PERCENTAGE_AND_TIME:
				{
					label += percentageFormatter.format(percentage) + ' % (' + timeFormatter.format(time) + ' ' + ResourceManager.getInstance().getString('CachegrindVisualizer', 'timeUnit') + ')';
				}
				break;
				
				case TYPE_TIME_AND_PERCENTAGE:
				{
					label += timeFormatter.format(time) + ' ' + ResourceManager.getInstance().getString('CachegrindVisualizer', 'timeUnit') + ' (' + percentageFormatter.format(percentage) + ' %)';
				}
				break;
				
				case TYPE_PERCENTAGE:
				{
					label += percentageFormatter.format(percentage) + ' %';
				}
				break;
					
				case TYPE_TIME:
				{
					label += timeFormatter.format(time) + ' ' + ResourceManager.getInstance().getString('CachegrindVisualizer', 'timeUnit');
				}
				break;
					
				default:
				{
					throw new Error('Unknown label type');
				}	
				break;				
			}
				
			return label;
		}
	}
}