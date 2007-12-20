package cachegrindVisualizer.controls.tree
{
	import mx.collections.ArrayCollection;
	
	public class TreeItem
	{
		public var left:int;
		public var right:int;
		public var level:uint;
		
		public var isBranch:Boolean;
		
		public var name:uint;		
		public var fileName:uint;
		
		public var children:ArrayCollection;
	}
}