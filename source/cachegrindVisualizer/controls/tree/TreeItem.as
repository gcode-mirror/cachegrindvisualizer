package cachegrindVisualizer.controls.tree
{
	import mx.collections.ArrayCollection;
	
	public class TreeItem
	{
		public var left:int;
		public var right:int;
		public var level:uint;
		
		public var isBranch:Boolean;
		
		public var name:String;		
		public var fileName:String;
		
		public var children:ArrayCollection;
	}
}