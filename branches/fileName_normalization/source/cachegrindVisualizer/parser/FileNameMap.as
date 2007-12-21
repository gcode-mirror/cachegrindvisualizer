package cachegrindVisualizer.parser
{
	import flash.data.SQLConnection;
	import flash.data.SQLStatement;
	
	public class FileNameMap
	{
		private var length:uint = 0;
		private var names:Array = new Array;
		private var namesMap:Array = new Array;
		private var sqlConnection:SQLConnection;
		private var isCompact:Boolean = false;
		
		public function FileNameMap(sqlConnection:SQLConnection):void
		{
			super();
			this.sqlConnection = sqlConnection;
		}

		public function addFile(name:String):uint
		{
			if(isCompact) {
				throw new Error("The map has been compacted already.");
			}
			if(namesMap[name] == null) {
				namesMap[name] = length;
				names[length] = name;
				length++;
			}
			return namesMap[name];
		}
		
		public function getFileId(name:String):int {			
			if(isCompact) {
				throw new Error("The map has been compacted already, therefore no name->id hash is available");
			}
			if(namesMap[name] == null) {
				return -1;
			} else {
				return namesMap[name];
			}
		}
		
		public function getFileName(id:uint):String {
			return names[id];
		}
		
		public function save():void {
			var statement:SQLStatement = new SQLStatement();
			statement.sqlConnection = sqlConnection;
			statement.text = 'insert into fileNames values (:id, :fileName)';

			for (var id:String in names)
			{
				statement.parameters[':id'] = id;
				statement.parameters[':fileName'] = names[id];
				statement.execute();
			}
		}
		
		public function reload(compact:Boolean = false):void
		{
			names = new Array();
			namesMap = new Array();
			isCompact = compact;
			
			var statement:SQLStatement = new SQLStatement();
			statement.sqlConnection = sqlConnection;				
			statement.text = 'select * from fileNames';
			statement.execute();
			for each (var item:Object in statement.getResult().data)
			{
				names[item.id] = item.fileName;
				if(isCompact) {
					namesMap[item.fileName] = item.id;
				}
			}
		}
		
		public function compact():void
		{
			isCompact = true;
			namesMap = new Array();
		}
		
		public function getArray():Array
		{
			return names;
		}
	}
}