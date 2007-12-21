package cachegrindVisualizer.parser
{
	import flash.data.SQLConnection;
	import flash.data.SQLStatement;
	
	/* abstract */ public class NameMap
	{	
		protected var namesMap:Object = new Object();
		protected var names:Object = new Object();
		
		protected var length:uint = 0;		
		
		protected var sqlStatement:SQLStatement = new SQLStatement();
		protected var table:String;
		
		public function NameMap(sqlConnection:SQLConnection, table:String):void
		{
			sqlStatement.sqlConnection = sqlConnection;
			this.table = table;
		}
		
		public function add(name:String):uint
		{
			if (!(name in namesMap)) 
			{
				namesMap[name] = length;
				names[length] = name;
				length++;
			}
			return namesMap[name];
		}
		
		public function save():Object
		{
			namesMap = null;
			
			sqlStatement.text = 'insert into ' + table + ' values (:id, :name)';

			for (var id:String in names)
			{
				sqlStatement.parameters[':id'] = id;
				sqlStatement.parameters[':name'] = names[id];
				sqlStatement.execute();
			}
			
			return names;
		}
		
		public function load():Object
		{				
			sqlStatement.text = 'select * from ' + table;
			sqlStatement.execute();
			for each (var item:Object in sqlStatement.getResult().data)
			{
				names[item.id] = item.name;
			}
			
			return names;
		}
	}
}