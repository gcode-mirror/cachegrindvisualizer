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
				
		protected var itemId:uint = 1;
		protected var fileReader:FileReader;
		
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
			}
		}
		
		protected function handleOpenSqlConnection(event:SQLEvent):void
		{
			sqlConnection.begin(SQLTransactionLockType.EXCLUSIVE);
			parse();
		}
		
		protected function parse(event:SQLEvent = null):void
		{					
			/*while (cursor > 4)
			{*/
				var insertSqlStatement:SQLStatement = new SQLStatement();
				insertSqlStatement.addEventListener(SQLErrorEvent.ERROR, handleSqlError);
				insertSqlStatement.text = 'insert into tree values (:id, :parent, :name, :fileName, :line, :time, :inclusiveTime)';
				insertSqlStatement.sqlConnection = sqlConnection;
				insertSqlStatement.parameters[':id'] = itemId;
				insertSqlStatement.parameters[':parent'] = 0;
				insertSqlStatement.parameters[':name'] = fileReader.getLine(fileReader.getLine(1).charAt(0) == 'f' ? 1 : 4).slice(3);
				insertSqlStatement.parameters[':fileName'] = '';
				insertSqlStatement.parameters[':line'] = 0;
				insertSqlStatement.parameters[':time'] = 0;
				insertSqlStatement.parameters[':inclusiveTime'] = 0;
				insertSqlStatement.execute();
	
				parseBody(itemId++);
			//}
			
			fileReader = null;
			sqlConnection.commit();
		}
				
		protected function parseBody(parentId:uint):void
		{				
			var children:Array = new Array();
			while (true)
			{					
				var lineAndTime:Array = fileReader.getLine(0).split(' ');				
				// нет детей
				if (fileReader.getLine(1).charAt(0) == 'f')
				{
					var updateSqlStatement:SQLStatement = new SQLStatement();
					updateSqlStatement.text = 'update tree set time = :time, fileName = :fileName where id = :id';
					updateSqlStatement.sqlConnection = sqlConnection;
					updateSqlStatement.parameters[':id'] = parentId;
					updateSqlStatement.parameters[':time'] = lineAndTime[1] / TIME_UNIT_IN_MS;							
					var fileName:String = fileReader.getLine(2);
					updateSqlStatement.parameters[':fileName'] = fileName == 'fl=php:internal' ? '' : fileName.slice(3);
					updateSqlStatement.execute();
					
					fileReader.shiftCursor(4);
					break;
				}
				else
				{
					var insertSqlStatement:SQLStatement = new SQLStatement();
					insertSqlStatement.text = 'insert into tree values (:id, :parent, :name, :fileName, :line, :time, :inclusiveTime)';
					insertSqlStatement.sqlConnection = sqlConnection;
					insertSqlStatement.parameters[':id'] = itemId;
					insertSqlStatement.parameters[':parent'] = parentId;
					insertSqlStatement.parameters[':name'] = fileReader.getLine(2).slice(4);
					insertSqlStatement.parameters[':fileName'] = '';
					insertSqlStatement.parameters[':line'] = lineAndTime[0];
					insertSqlStatement.parameters[':time'] = 0;
					insertSqlStatement.parameters[':inclusiveTime'] = lineAndTime[1] / TIME_UNIT_IN_MS;
					insertSqlStatement.execute();
			
					children.push(itemId++);					
		
					var sample:String = fileReader.getLine(4).charAt(0);
					// следующий ребенок (cfn)
					if (sample == 'c')
					{
						fileReader.shiftCursor(3);
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
			updateSqlStatement.addEventListener(SQLErrorEvent.ERROR, handleSqlError);
			updateSqlStatement.text = 'update tree set time = :time, fileName = :fileName where id = :id';
			updateSqlStatement.sqlConnection = sqlConnection;
			updateSqlStatement.parameters[':id'] = parentId;
			
			var lineAndTime:Array = fileReader.getLine(3).split(' ');
			updateSqlStatement.parameters[':time'] = lineAndTime[1] / TIME_UNIT_IN_MS;
			
			if (sample == 'f')
			{
				updateSqlStatement.parameters[':fileName'] = fileReader.getLine(5).slice(3);
				fileReader.shiftCursor(7);
			}
			// для функции main не указывается файл, есть строка summary, отделенная пустыми строками
			else if (sample == '' || sample == 's')
			{
				updateSqlStatement.parameters[':fileName'] = fileReader.getLine(8).slice(3);
				//parent.inclusiveTime = fileReader.data[cursor - 5].slice(9) / TIME_UNIT_IN_MS;
			
				fileReader.shiftCursor(10);
			}
			else
			{
				throw new Error('Unknown format or analyzer error');
			}
			
			updateSqlStatement.execute();
		}
		
		protected function handleSqlError(event:SQLErrorEvent):void
		{
				
		}
	}
}