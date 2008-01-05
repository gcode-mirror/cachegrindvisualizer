package cachegrindVisualizer.parser
{
	import flash.data.SQLConnection;
	import flash.data.SQLStatement;
	
	public class NameMap
	{	
		protected var map:Object = new Object();
		protected var values:Object = new Object();
		
		protected var id:uint = 0;		
		
		protected var sqlStatement:SQLStatement = new SQLStatement();
		protected var table:String;
		
		public function NameMap(sqlConnection:SQLConnection = null, table:String = null):void
		{
			sqlStatement.sqlConnection = sqlConnection;
			this.table = table;
		}
		
		public function add(name:String):uint
		{
			if (!(name in map)) 
			{
				map[name] = id;
				values[id] = name;
				id++;
			}
			return map[name];
		}
		
		public function save():Object
		{
			map = null;
			
			sqlStatement.text = 'insert into ' + table + ' values (:id, :value)';
			for (var id:String in values)
			{
				sqlStatement.parameters[':id'] = id;
				sqlStatement.parameters[':value'] = values[id];
				sqlStatement.execute();
			}
			
			return values;
		}
		
		public function load():Object
		{				
			sqlStatement.text = 'select * from ' + table;
			sqlStatement.execute();
			for each (var item:Object in sqlStatement.getResult().data)
			{
				values[item.id] = item.value;
			}
			
			return values;
		}
	}
}