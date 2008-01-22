package cachegrindVisualizer.parser
{
	import cachegrindVisualizer.controls.tree.TreeItem;
	
	import flash.filesystem.File;
	
	/**
	 * @pattern TDO
	 */
	public class ParserResult
	{
		public var mainTreeItem:TreeItem = new TreeItem();
		public var db:File;
		
		public var names:Object;
		public var fileNames:Object;
		
		public function ParserResult():void
		{
			mainTreeItem.isBranch = true;
		}
	}
}