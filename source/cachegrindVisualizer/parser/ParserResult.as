package cachegrindVisualizer.parser
{
	import flash.filesystem.File;
	
	import cachegrindVisualizer.controls.tree.TreeItem;
	
	/**
	 * @pattern TDO
	 */
	public class ParserResult
	{
		public var mainTreeItem:TreeItem = new TreeItem();
		public var db:File;
		
		public var names:Object = new Object();
		public var fileNames:Object = new Object();
		
		public function ParserResult():void
		{
			mainTreeItem.isBranch = true;
		}
	}
}