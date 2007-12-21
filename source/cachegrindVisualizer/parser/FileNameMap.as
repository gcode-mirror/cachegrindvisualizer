package cachegrindVisualizer.parser
{
	import flash.data.SQLConnection;
	import flash.data.SQLStatement;
	
	public class FileNameMap
	{
		private var length:uint = 0;
		private var names:Object = new Object;
		private var namesMap:Object = new Object;
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
				throw new Error("Map has been compacted already.");
			}
			var id:uint = getFileId(name);
			if(id) {
				return id; 
			} else {
				namesMap[name] = length;
				return length++;
			}
		}
		
		public function getFileId(name:String):uint {			
			if(isCompact) {
				throw new Error("Map has been compacted already, therefore no name->id hash is available");
			}
			return namesMap[name];
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
			names = new Object();
			namesMap = new Object();
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
			namesMap = new Object();
		}
		
		public function getArray():Object
		{
			return names;
		}
	}
}