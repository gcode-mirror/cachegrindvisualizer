package develar.cachegrindVisualizer.parser
{	
	import flash.system.System;	
	import flash.filesystem.File;
	import flash.data.SQLConnection;
	import flash.data.SQLTransactionLockType;
	import flash.data.SQLStatement;
	import flash.events.Event;
	import flash.events.SQLEvent;
	import flash.events.SQLErrorEvent;
	import flash.events.ProgressEvent;
	
	import develar.formatters.Formatter;	
	
	import develar.cachegrindVisualizer.Item;
	
	public class Parser
	{
		public static const MAIN_FUNCTION_NAME:String = 'main';		
		protected static const INITIAL_DB_FILE_NAME:String = 'db.db';		

		/**
		 * Курс преобразования стоимости в милисекунды
		 */	
		protected static const TIME_UNIT_IN_MS:uint = 10000;
				
		protected var cursor:uint = 0;
		protected var itemId:uint = 1;
		protected var fileReader:FileReader;
		
		//protected var insertSqlStatement:SQLStatement = new SQLStatement();
		protected var updateSqlStatement:SQLStatement = new SQLStatement();
		
		protected var _sqlConnection:SQLConnection = new SQLConnection();
		public function get sqlConnection():SQLConnection
		{
			return _sqlConnection;
		}
			
		public function Parser(file:File):void
		{
			fileReader = new FileReader(file);
			trace('память: ', Formatter.dataSize(System.totalMemory));
			var dbFile:File = File.applicationStorageDirectory.resolvePath(fileReader.checksum + '.db');			
			if (/*dbFile.exists*/false)
			{
				sqlConnection.open(dbFile);
			}
			else
			{
				File.applicationResourceDirectory.resolvePath(INITIAL_DB_FILE_NAME).copyTo(dbFile, true);
				sqlConnection.addEventListener(SQLEvent.OPEN, handleOpenSqlConnection);
				sqlConnection.open(dbFile);
							
				fileReader.read();
				//parse();				
			}
		}
		
		protected function handleOpenSqlConnection(event:SQLEvent):void
		{
			sqlConnection.begin(SQLTransactionLockType.EXCLUSIVE);
			parse();	
			
			/*insertSqlStatement.text = 'insert into tree values (:id, :parent, :name, :fileName, :line, :time, :inclusiveTime)';
			insertSqlStatement.sqlConnection = sqlConnection;
			insertSqlStatement.addEventListener(SQLErrorEvent.ERROR, handleError);
			updateSqlStatement.addEventListener(SQLEvent.PREPARE, parse);
			insertSqlStatement.prepare();*/
			
			
			/*updateSqlStatement.addEventListener(SQLErrorEvent.ERROR, handleError);
			updateSqlStatement.addEventListener(SQLEvent.PREPARE, parse);
			updateSqlStatement.prepare();*/
		}
		
		protected function handleError(event:SQLErrorEvent):void
		{
			
		}
		
		protected function parse(event:SQLEvent = null):void
		{
			if (/*insertSqlStatement.prepared && */true)
			{
				cursor = fileReader.data.length - 1;	
					
				while (cursor > 4)
				{
					var insertSqlStatement:SQLStatement = new SQLStatement();
					insertSqlStatement.addEventListener(SQLErrorEvent.ERROR, handleError);
					insertSqlStatement.text = 'insert into tree values (:id, :parent, :name, :fileName, :line, :time, :inclusiveTime)';
					insertSqlStatement.sqlConnection = sqlConnection;
					insertSqlStatement.parameters[':id'] = itemId;
					insertSqlStatement.parameters[':parent'] = 0;
					insertSqlStatement.parameters[':name'] = fileReader.data[cursor - (fileReader.data[cursor - 1].charAt(0) == 'f' ? 1 : 4)].slice(3);
					insertSqlStatement.parameters[':fileName'] = '';
					insertSqlStatement.parameters[':line'] = 0;
					insertSqlStatement.parameters[':time'] = 0;
					insertSqlStatement.parameters[':inclusiveTime'] = 0;
					insertSqlStatement.execute();
	
					parseBody(itemId++);
				}
				
				fileReader = null;
				sqlConnection.commit();				
				
				/*var result_length:uint = result.length;
				if (result_length > 1)
				{
					for (var i:uint = 1; i < result_length; i++)
					{
						var parent:Item = result[i];
						if (parent.children == null)
						{
							parent.inclusiveTime = parent.time;
						}
						else
						{
							for each (var child:Item in parent.children)
							{
								parent.inclusiveTime += child.inclusiveTime;
							}
						}
						
						result[0].children.push(parent);
						result[0].inclusiveTime += parent.inclusiveTime;
					}
				}*/
			}
		}
				
		protected function parseBody(parentId:uint):void
		{				
			var children:Array = new Array();
			while (true)
			{					
				var line_and_time:Array = fileReader.data[cursor].split(' ');				
				// нет детей
				if (fileReader.data[cursor - 1].charAt(0) == 'f')
				{
					var updateSqlStatement:SQLStatement = new SQLStatement();
					updateSqlStatement.text = 'update tree set time = :time, fileName = :fileName where id = :id';
					updateSqlStatement.sqlConnection = sqlConnection;
					updateSqlStatement.parameters[':id'] = parentId;
					updateSqlStatement.parameters[':time'] = line_and_time[1] / TIME_UNIT_IN_MS;							
					var fileName:String = fileReader.data[cursor - 2];
					updateSqlStatement.parameters[':fileName'] = fileName == 'fl=php:internal' ? '' : fileName.slice(3);
					updateSqlStatement.execute();
					
					cursor -= 4;
					break;
				}
				else
				{
					var insertSqlStatement:SQLStatement = new SQLStatement();
					insertSqlStatement.text = 'insert into tree values (:id, :parent, :name, :fileName, :line, :time, :inclusiveTime)';
					insertSqlStatement.sqlConnection = sqlConnection;
					insertSqlStatement.parameters[':id'] = itemId;
					insertSqlStatement.parameters[':parent'] = parentId;
					insertSqlStatement.parameters[':name'] = fileReader.data[cursor - 2].slice(4);
					insertSqlStatement.parameters[':fileName'] = '';
					insertSqlStatement.parameters[':line'] = line_and_time[0];
					insertSqlStatement.parameters[':time'] = 0;
					insertSqlStatement.parameters[':inclusiveTime'] = line_and_time[1] / TIME_UNIT_IN_MS;
					insertSqlStatement.execute();
			
					children.push(itemId++);					
		
					var sample:String = fileReader.data[cursor - 4].charAt(0);
					// следующий ребенок (cfn)
					if (sample == 'c')
					{
						cursor -= 3;
					}
					// данные о родителе после всех детей
					else
					{
						updateParentItem(parentId, sample);
		
						for each (var childId:uint in children)
						{
							parseBody(childId);
						}
												
						break;
					}
				}
			}
		}
		
		protected function updateParentItem(parentId:uint, sample:String):void
		{
			var updateSqlStatement:SQLStatement = new SQLStatement();
			updateSqlStatement.addEventListener(SQLErrorEvent.ERROR, handleError);
			updateSqlStatement.text = 'update tree set time = :time, fileName = :fileName where id = :id';
			updateSqlStatement.sqlConnection = sqlConnection;
			updateSqlStatement.parameters[':id'] = parentId;
			
			var line_and_time:Array = fileReader.data[cursor - 3].split(' ');
			updateSqlStatement.parameters[':time'] = line_and_time[1] / TIME_UNIT_IN_MS;
			
			if (sample == 'f')
			{
				updateSqlStatement.parameters[':fileName'] = fileReader.data[cursor - 5].slice(3);
				cursor -= 7;
			}
			// для функции main не указывается файл, есть строка summary, отделенная пустыми строками
			else if (sample == '' || sample == 's')
			{
				updateSqlStatement.parameters[':fileName'] = fileReader.data[cursor - 8].slice(3);
				//parent.inclusiveTime = fileReader.data[cursor - 5].slice(9) / TIME_UNIT_IN_MS;
			
				cursor -= 10;
			}
			else
			{
				throw new Error('Unknown format or analyzer error');
			}
			
			updateSqlStatement.execute();
		}
	}
}