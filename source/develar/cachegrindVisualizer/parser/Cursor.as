package develar.cachegrindVisualizer.parser
{
	import develar.cachegrindVisualizer.controls.tree.TreeItem;
	
	import flash.data.SQLStatement;
	import flash.events.SQLErrorEvent;
	
	internal class Cursor
	{
		public var id:uint;
		public var mainTreeItem:TreeItem = new TreeItem();
		public var inclusiveTime:Object = new Object();
		public var insertStatement:SQLStatement = new SQLStatement();
		
		public function Cursor()
		{
			id = DatabaseOpener.MAIN_FUNCTION_ID + 1;
			insertStatement.text = 'insert into main.tree (id, path, name, fileName, line, time, inclusiveTime) values (:id, :path, :name, :fileName, :line, :time, :inclusiveTime)';
			insertStatement.addEventListener(SQLErrorEvent.ERROR, handleInsertError);
			
			mainTreeItem.id = DatabaseOpener.MAIN_FUNCTION_ID;
			mainTreeItem.name = DatabaseOpener.MAIN_FUNCTION_NAME;
			mainTreeItem.isBranch = true;
			mainTreeItem.path = DatabaseOpener.MAIN_FUNCTION_PATH;
		}
		
		private function handleInsertError(event:SQLErrorEvent):void
		{
			
		}
	}
}