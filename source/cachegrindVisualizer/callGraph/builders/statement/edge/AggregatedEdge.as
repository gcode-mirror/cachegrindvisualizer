package cachegrindVisualizer.callGraph.builders.statement.edge
{
	public class AggregatedEdge extends Edge
	{
		public var number:uint;
		
		public var parentName:uint;
		
		public var summaryInclusiveTime:Number;
		public var averageInclusiveTime:Number;
		public var minimumInclusiveTime:Number;
		public var maximumInclusiveTime:Number;		
	}
}