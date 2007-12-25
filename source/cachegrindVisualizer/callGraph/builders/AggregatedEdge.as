package cachegrindVisualizer.callGraph.builders
{
	public class AggregatedEdge extends Edge
	{
		public var number:uint;
		public var namesPath:String;
		
		public var summaryTime:Number;
		public var averageTime:Number;
		
		public var summaryInclusiveTime:Number;
		public var averageInclusiveTime:Number;
		
		public var summaryPercentage:Number;
	}
}