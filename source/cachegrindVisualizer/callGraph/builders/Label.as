package cachegrindVisualizer.callGraph.builders
{
	import develar.formatters.NumberFormatter;
	
	import mx.formatters.NumberBaseRoundType;
	
	public class Label
	{
		public static const TYPE_PERCENTAGE:uint = 0;
		public static const TYPE_TIME:uint = 1;
		public static const TYPE_PERCENTAGE_AND_TIME:uint = 2;
		public static const TYPE_TIME_AND_PERCENTAGE:uint = 3;
		
		public static const TYPE_NO:uint = 4;
		
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
		
		public function head(edge:Edge):String
		{			
			return build(edge.percentage, edge.time);
		}
		
		public function node(node:Node):String
		{
			var label:String = node.name.replace(/\\/g, '\\\\') + '\\n';
			if (type != TYPE_NO)
			{
				label = build(node.inclusivePercentage, node.inclusiveTime, label);
			}
			return label;
		}
		
		protected function build(percentage:Number, time:uint, label:String = ''):String
		{			
			switch (_type)
			{
				case TYPE_PERCENTAGE_AND_TIME:
				{
					label += percentageFormatter.format(percentage) + ' % (' + timeFormatter.format(time) + ')';
				}
				break;
				
				case TYPE_TIME_AND_PERCENTAGE:
				{
					label += timeFormatter.format(time) + ' (' + percentageFormatter.format(percentage) + ' %)';
				}
				break;
				
				case TYPE_PERCENTAGE:
				{
					label += percentageFormatter.format(percentage) + ' %';
				}
				break;
					
				case TYPE_TIME:
				{
					label += timeFormatter.format(time);
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