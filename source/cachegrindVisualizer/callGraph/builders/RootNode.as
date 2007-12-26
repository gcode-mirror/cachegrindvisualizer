package cachegrindVisualizer.callGraph.builders
{
	public class RootNode extends Node
	{		
		public var namesParentPath:String;
		public var parentName:String;
		
		public var time:Number;
		
		public function RootNode():void
		{
			inclusivePercentage = 100;
		}
	}
}