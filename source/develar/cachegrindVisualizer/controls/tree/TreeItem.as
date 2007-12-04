package develar.cachegrindVisualizer.controls.tree
{
	import mx.collections.ArrayCollection;
	
	public class TreeItem
	{
		public var id:uint;
		public var path:String;
		public var isBranch:Boolean;
		
		public var name:String;		
		public var fileName:String;
		
		public var children:ArrayCollection;
	}
}