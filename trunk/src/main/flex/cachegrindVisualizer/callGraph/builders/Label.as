package cachegrindVisualizer.callGraph.builders
{
	import cachegrindVisualizer.callGraph.builders.edge.AggregatedEdge;
	import cachegrindVisualizer.callGraph.builders.edge.Edge;
	
	import develar.formatters.NumberFormatter;
	import develar.utils.StringUtil;
	
	import mx.formatters.NumberBaseRoundType;
	
	public class Label
	{
		public static const TYPE_PERCENTAGE:uint = 0;
		public static const TYPE_TIME:uint = 1;
		public static const TYPE_PERCENTAGE_AND_TIME:uint = 2;
		public static const TYPE_TIME_AND_PERCENTAGE:uint = 3;
		
		public static const TYPE_NO:uint = 4;
		
		private static const INCLUDE_FUNCTIONS:Object = {'include': null, 'include_once': null, 'require': null, 'require_once': null};
			
		private static const TIME_PRECISION:int = 0;
		private static const PERCENTAGE_PRECISION:uint = 2;
		
		private static var percentageFormatter:NumberFormatter = new NumberFormatter();
		private static var timeFormatter:NumberFormatter = new NumberFormatter();
		
		public function Label():void
		{			
			timeFormatter.precision = TIME_PRECISION;
			timeFormatter.rounding = NumberBaseRoundType.NEAREST;
			
			percentageFormatter.precision = PERCENTAGE_PRECISION;
			percentageFormatter.rounding = NumberBaseRoundType.NEAREST;
		}
		
		private var _type:uint = TYPE_PERCENTAGE_AND_TIME;
		public function set type(value:uint):void
		{
			_type = value;
		}
		
		public function get needPercentage():Boolean
		{
			return _type == TYPE_PERCENTAGE_AND_TIME || _type == TYPE_TIME_AND_PERCENTAGE || _type == TYPE_PERCENTAGE;
		}
		
		public function edge(edge:Edge):String
		{		
			var result:String = '';
			if (_type != Label.TYPE_NO)
			{
				result += 'label="' + build(edge.inclusivePercentage, edge.inclusiveTime) + '"';
				// если узел не имеет детей (то есть собственное время равно включенному), то смысла в метке острия ребра нет - она всегда будет равна метке ребра
				if (edge.time > 0 && edge.time != edge.inclusiveTime)
				{
					result += ' headlabel="' + build(edge.percentage, edge.time) + '"';
				}
			}	
			return result;
		}
		
		public function aggregatedEdge(edge:AggregatedEdge, onePercentage:Number):String
		{						
			if (_type == TYPE_NO && edge.number > 1)
			{
				return 'label="×' + edge.number + '"';
			}
			else
			{
				var result:String = '';
				var maximumInclusivePercentage:Number;
				result += 'label="';
				if (edge.number > 1)
				{
					if (needPercentage)
					{
						var summaryInclusivePercentage:Number = edge.summaryInclusiveTime / onePercentage;
						var averageInclusivePercentage:Number = edge.averageInclusiveTime / onePercentage;					
						var minimumInclusivePercentage:Number = edge.minimumInclusiveTime / onePercentage;
						maximumInclusivePercentage = edge.maximumInclusiveTime / onePercentage;
						
						var percentageLabel:String =  percentageFormatter.format(summaryInclusivePercentage) + '%=' + edge.number + '×[' + percentageFormatter.format(minimumInclusivePercentage) + '%..' + percentageFormatter.format(averageInclusivePercentage) + '%..' + percentageFormatter.format(maximumInclusivePercentage) + '%]';
					}
					var timeLabel:String = timeFormatter.format(edge.summaryInclusiveTime) + '=' + edge.number + '×[' + timeFormatter.format(edge.minimumInclusiveTime) + '..' + timeFormatter.format(edge.averageInclusiveTime) + '..' + timeFormatter.format(edge.maximumInclusiveTime) + ']';
					
					switch (_type)
					{
						case TYPE_PERCENTAGE_AND_TIME:
						{
							result += percentageLabel + '\\n(' + timeLabel + ')';
						}
						break;
						
						case TYPE_TIME_AND_PERCENTAGE:
						{
							result += timeLabel + '\\n(' + percentageLabel + ')';
						}
						break;
						
						case TYPE_PERCENTAGE:
						{
							result += percentageLabel;
						}
						break;
							
						case TYPE_TIME:
						{
							result += timeLabel;
						}
						break;
							
						default:
						{
							throw new Error('Unknown label type');
						}	
						break;			
					}
				}
				else
				{
					if (_type != TYPE_TIME)
					{
						maximumInclusivePercentage = edge.maximumInclusiveTime / onePercentage;
					}
					result += build(maximumInclusivePercentage, edge.maximumInclusiveTime);
				}
				return result + '"';
			}
		}
		
		public function node(node:Node, onePercentage:Number, builder:Builder):String
		{
			var name:String = builder.names[node.name];
			
			var label:String = 'label="';			
			var parts:Array = name.split('::', 2);
			if (parts.length == 2 && parts[0] in INCLUDE_FUNCTIONS)
			{
				label += parts[0] + '::' + StringUtil.truncatePathname(parts[1]).replace(/\\/g, '\\\\');
			}
			else
			{
				label += name;
			}	
			
			if (_type != TYPE_NO)
			{
				var inclusivePercentage:Number;
				if (needPercentage)
				{
					inclusivePercentage = node.inclusiveTime / onePercentage;
				}
				label += '\\n' + build(inclusivePercentage, node.inclusiveTime);
			}
			return label + '"';
		}
		
		protected function build(percentage:Number, time:Number):String
		{			
			switch (_type)
			{
				case TYPE_PERCENTAGE_AND_TIME:
				{
					return percentageFormatter.format(percentage) + ' % (' + timeFormatter.format(time) + ')';
				}
				break;
				
				case TYPE_TIME_AND_PERCENTAGE:
				{
					return timeFormatter.format(time) + ' (' + percentageFormatter.format(percentage) + ' %)';
				}
				break;
				
				case TYPE_PERCENTAGE:
				{
					return percentageFormatter.format(percentage) + ' %';
				}
				break;
					
				case TYPE_TIME:
				{
					return timeFormatter.format(time);
				}
				break;
					
				default:
				{
					throw new Error('Unknown label type');
				}	
				break;				
			}
		}
	}
}