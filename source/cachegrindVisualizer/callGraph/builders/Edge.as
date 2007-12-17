package cachegrindVisualizer.callGraph.builders
{
	public class Edge
	{
		public var id:uint;
		public var path:String;
		
		public var name:String;
		
		public var time:Number;
		public var inclusiveTime:Number;
		
		public var percentage:Number;
		public var inclusivePercentage:Number;
		
		public var arrowLabel:String = '';
		
		public var isBranch:Boolean;
	}
}