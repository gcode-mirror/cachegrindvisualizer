package develar.cachegrindVisualizer.callGraph
{
	import mx.resources.ResourceBundle;	
	import mx.formatters.NumberBaseRoundType;
	
	import develar.formatters.NumberFormatter;
	
	import develar.cachegrindVisualizer.Item;
	
	public class LabelCreator
	{
		public static const TYPE_PERCENTAGE:uint = 0;
		public static const TYPE_TIME:uint = 1;
		public static const TYPE_PERCENTAGE_AND_TIME:uint = 2;
		public static const TYPE_TIME_AND_PERCENTAGE:uint = 3;
		
		protected const PERCENTAGE_PRECISION:uint = 2;
		
		protected var percentageFormatter:NumberFormatter = new NumberFormatter();
		protected var timeFormatter:NumberFormatter = new NumberFormatter();
		protected var timeUnit:String = ResourceBundle.getResourceBundle('CachegrindVisualizer').getString('timeUnit');
		
		protected var _type:uint = 2;
		public function get type():uint
		{
			return _type;
		}
		public function set type(value:uint):void
		{
			_type = value;
		}
		
		public function LabelCreator():void
		{
			timeFormatter.precision = -1;
			
			percentageFormatter.precision = PERCENTAGE_PRECISION;
			percentageFormatter.rounding = NumberBaseRoundType.NEAREST;
		}
		
		public function arrow(item:Item):String
		{			
			return create(item.inclusiveTime, item.inclusivePercentage);
		}
		
		public function arrowHeadOrTail(item:Item, one_percentage:Number):String
		{			
			return create(item.time / one_percentage, item.time);
		}
		
		public function node(nodeName:String, node:Node):String
		{
			return create(node.inclusivePercentage, node.inclusiveTime, nodeName);
		}
		
		protected function create(percentage:Number, time:uint, nodeName:String = null):String
		{
			var label:String = '';
			
			if (nodeName != null)
			{
				// Graphviz воспринимает \ как управляющий символ, поэтому его необходимо экранировать
				label = nodeName.replace(/\\/g, '\\\\') + '\\n';
			}
			
			switch (_type)
			{
				case TYPE_PERCENTAGE:
				{
					label += percentageFormatter.format(percentage) + ' %';
				}
				break;
					
				case TYPE_TIME:
				{
					label += timeFormatter.format(time) + ' ' + timeUnit;
				}
				break;
					
				case TYPE_PERCENTAGE_AND_TIME:
				{
					label += percentageFormatter.format(percentage) + ' % (' + timeFormatter.format(time) + ' ' + timeUnit + ')';
				}
				break;
					
				case TYPE_TIME_AND_PERCENTAGE:
				{
					label += timeFormatter.format(time) + ' ' + timeUnit + ' (' + percentageFormatter.format(percentage) + ' %)';
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