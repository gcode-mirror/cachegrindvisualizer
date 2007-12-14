package develar.cachegrindVisualizer.parser
{
	import develar.cachegrindVisualizer.controls.tree.TreeItem;
	
	import flash.data.SQLStatement;
	import flash.events.SQLErrorEvent;
	
	import mx.controls.Alert;
	
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
			insertStatement.addEventListener(SQLErrorEvent.ERROR, handleInsertError, false, 0, true);
		}
		
		private function handleInsertError(event:SQLErrorEvent):void
		{
			 Alert.show(event.error.toString());
		}
	}
}