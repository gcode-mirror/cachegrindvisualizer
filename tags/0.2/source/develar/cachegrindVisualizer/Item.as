package develar.cachegrindVisualizer
{
	public class Item
	{
		public var name:String;
		public var fileName:String;
		
		public var line:uint;
		
		public var time:uint;		
		public var inclusiveTime:uint;
		
		public var percentage:Number;
		public var inclusivePercentage:Number;
		
		public var children:Array;
	}
}