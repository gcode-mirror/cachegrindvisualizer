package cachegrindVisualizer.parser
{
	import flash.data.SQLConnection;
	import flash.data.SQLStatement;
	
	public class FunctionMap
	{
		private var length:uint = 0;
		private var names:Object = new Object;
		private var namesMap:Object = new Object;
		private var sqlConnection:SQLConnection;
		private var isCompact:Boolean = false;
		
		public function FunctionMap(sqlConnection:SQLConnection):void
		{
			super();
			this.sqlConnection = sqlConnection;
		}

		public function addFunction(name:String):uint
		{
			if(isCompact) {
				throw new Error("Map has been compacted already.");
			}
			var id:uint = getFunctionId(name);
			if(id) {
				return id; 
			} else {
				namesMap[name] = length;
				return length++;
			}
		}
		
		public function getFunctionId(name:String):uint {			
			if(isCompact) {
				throw new Error("Map has been compacted already, therefore no name->id hash is available");
			}
			return namesMap[name];
		}
		
		public function getFunctionName(id:uint):String {
			return names[id];
		}
		
		public function save():void {
			var statement:SQLStatement = new SQLStatement();
			statement.sqlConnection = sqlConnection;
			statement.text = 'insert into names values (:id, :name)';

			for (var id:String in names)
			{
				statement.parameters[':id'] = id;
				statement.parameters[':name'] = names[id];
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
			statement.text = 'select * from names';
			statement.execute();
			for each (var item:Object in statement.getResult().data)
			{
				names[item.id] = item.name;
				if(isCompact) {
					namesMap[item.name] = item.id;
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