package cachegrindVisualizer.parser
{
	import flash.data.SQLConnection;
	import flash.data.SQLStatement;
	
	public class FunctionMap
	{
		private var length:uint = 0;
		private var names:Array = new Array;
		private var namesMap:Array = new Array;
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
				throw new Error("The map has been compacted already.");
			}
			if(namesMap[name] == null) {
				namesMap[name] = length;
				names[length] = name;
				length++;
			}
			return namesMap[name];
		}
		
		public function getFunctionId(name:String):int {			
			if(isCompact) {
				throw new Error("The map has been compacted already, therefore no name->id hash is available");
			}
			if(namesMap[name] == null) {
				return -1;
			} else {
				return namesMap[name];
			}
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
			names = new Array();
			namesMap = new Array();
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
			namesMap = new Array();
		}
		
		public function getArray():Array
		{
			return names;
		}
	}
}