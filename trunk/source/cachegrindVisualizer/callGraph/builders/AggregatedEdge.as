package cachegrindVisualizer.callGraph.builders
{
	public class AggregatedEdge extends Edge
	{
		public var number:uint;
		
		public var parentName:String;
		public var namesParentPath:String;
		
		public var summaryTime:Number;
		public var averageTime:Number;
		
		public var summaryInclusiveTime:Number;
		public var averageInclusiveTime:Number;
		
		public var summaryPercentage:Number;
	}
}