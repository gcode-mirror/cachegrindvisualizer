package cachegrindVisualizer.callGraph.builders
{
	public class Grouper
	{
		public static const NODES_AND_CALLS:uint = 0;
		public static const NODES:uint = 1;
		public static const CALLS:uint = 2;
		public static const NO:uint = 3;
		
		private var _type:uint = NODES_AND_CALLS;
		public function set type(value:uint):void
		{
			_type = value;
		}
		
		public function get sql():String
		{
			switch (_type)
			{
				case NODES_AND_CALLS:
				{
					return 'select name, parentName, count(*) as number, sum(time), avg(time), sum(inclusiveTime), avg(inclusiveTime), sum(time) / :onePercentage as percentage, inclusiveTime / :onePercentage as inclusivePercentage';
				}
				break;
				
				case NODES:
				{
					return 'select name, parentName, time, inclusiveTime, time / :onePercentage as percentage, inclusiveTime / :onePercentage as inclusivePercentage from tree';
				}
				break;
					
				default:
				{
					throw new Error('Unknown grouping');
				}	
				break;				
			}
		}
	}
}