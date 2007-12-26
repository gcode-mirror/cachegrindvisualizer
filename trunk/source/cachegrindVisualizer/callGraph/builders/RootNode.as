package cachegrindVisualizer.callGraph.builders
{
	public class RootNode extends Node
	{		
		public var namesPath:uint;
		
		public var time:Number;
		
		public function RootNode():void
		{
			inclusivePercentage = 100;
		}
	}
}