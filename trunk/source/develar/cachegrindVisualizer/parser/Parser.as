package develar.cachegrindVisualizer.parser
{	
	import develar.formatters.Formatter;
	import develar.utils.SqlUtil;
	
	import flash.data.SQLConnection;
	import flash.data.SQLStatement;
	import flash.data.SQLTransactionLockType;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.SQLEvent;
	import flash.filesystem.File;
	import flash.system.System;
	
	public class Parser extends EventDispatcher
	{
		public static const MAIN_FUNCTION_NAME:String = 'main';		
		protected static const INITIAL_DB_FILE_NAME:String = 'db.db';		

		/**
		 * Курс преобразования стоимости в милисекунды
		 */	
		protected static const TIME_UNIT_IN_MS:uint = 10000;
				
		protected var itemId:uint = 1;
		protected var sqlConnection:SQLConnection = new SQLConnection();
		protected var fileReader:FileReader;
		/**
		 * Мы выполняем запросы асинхронно, поэтому нам нужен счетчик чтобы знать, когда все операции завершены
		 */
		protected var executingSqlStatementAmount:uint;		
			
		public function Parser(file:File):void
		{
			fileReader = new FileReader(file);
			trace('память: ', Formatter.dataSize(System.totalMemory));
			_dbFile = File.applicationStorageDirectory.resolvePath(fileReader.checksum + '.db');			
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
		
		protected var _dbFile:File;
		public function get dbFile():File
		{
			return _dbFile;
		}
		
		protected function handleOpenSqlConnection(event:SQLEvent):void
		{
			sqlConnection.begin(SQLTransactionLockType.EXCLUSIVE);
			parseBody(0);
			fileReader = null;			
			checkComplete();			
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
					// деструкторы вне main, то есть сами по себе
					if (parentId == 0)
					{
						var tmp:String = 'ff';
						tmp += 'hh';
						/*var insertSqlStatement:SQLStatement = new SQLStatement();
						insertSqlStatement.text = 'insert into tree (id, name, fileName, ) values (:id, :name, :fileName, :time, :inclusiveTime)';
						insertSqlStatement.text = 'insert into tree values (:id, :parent, :name, :fileName, :line, :time, :inclusiveTime)';
						insertSqlStatement.parameters[':id'] = itemId;
						insertSqlStatement.parameters[':name'] = fileReader.getLine(1).slice(3);
						insertSqlStatement.parameters[':fileName'] = fileReader.getLine(2).slice(3); // здесь никогда не будет php:internal
						insertSqlStatement.parameters[':time'] = lineAndTime[0] / TIME_UNIT_IN_MS;*/
					}
					else
					{
						var updateSqlStatement:SQLStatement = createSqlStatement();
						updateSqlStatement.text = 'update tree set time = :time, fileName = :fileName where id = :id';
						updateSqlStatement.parameters[':id'] = parentId;
						updateSqlStatement.parameters[':time'] = convertTime(lineAndTime[1]);							
						var fileName:String = fileReader.getLine(2);
						updateSqlStatement.parameters[':fileName'] = fileName == 'fl=php:internal' ? null : fileName.slice(3); // не храним php:internal для экономии, - раз null, значит это php:internal
						updateSqlStatement.execute();
						executingSqlStatementAmount++;
						
						fileReader.shiftCursor(4);						
					}
					break;
				}
				else
				{
					var insertSqlStatement:SQLStatement = createSqlStatement();
					insertSqlStatement.text = 'insert into tree values (:id, :parent, :name, :fileName, :line, :time, :inclusiveTime)';
					insertSqlStatement.parameters[':id'] = itemId;
					insertSqlStatement.parameters[':parent'] = parentId;
					insertSqlStatement.parameters[':name'] = fileReader.getLine(2).slice(4);
					insertSqlStatement.parameters[':fileName'] = null;
					insertSqlStatement.parameters[':line'] = lineAndTime[0];
					insertSqlStatement.parameters[':time'] = 0;
					insertSqlStatement.parameters[':inclusiveTime'] = convertTime(lineAndTime[1]);
					insertSqlStatement.execute();
					executingSqlStatementAmount++;
			
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
			var lineAndTime:Array = fileReader.getLine(3).split(' ');
			
			if (sample == 'f')
			{
				if (parentId != 0)
				{
					var updateSqlStatement:SQLStatement = createSqlStatement();
					updateSqlStatement.text = 'update tree set time = :time, fileName = :fileName where id = :id';
					updateSqlStatement.parameters[':id'] = parentId;
					updateSqlStatement.parameters[':time'] = convertTime(lineAndTime[1]);
					updateSqlStatement.parameters[':fileName'] = fileReader.getLine(5).slice(3);
					updateSqlStatement.execute();
					executingSqlStatementAmount++;			
				}
				fileReader.shiftCursor(7);
			}
			// для функции main не указывается файл, есть строка summary, отделенная пустыми строками
			else if (sample == '' || sample == 's')
			{
				var insertSqlStatement:SQLStatement = createSqlStatement();			
				insertSqlStatement.text = 'insert into tree (id, name, fileName, time, inclusiveTime) values (:id, :name, :fileName, :time, :inclusiveTime)';
				insertSqlStatement.parameters[':id'] = itemId;
				insertSqlStatement.parameters[':name'] = MAIN_FUNCTION_NAME;
				insertSqlStatement.parameters[':fileName'] = fileReader.getLine(8).slice(3);
				insertSqlStatement.parameters[':time'] = convertTime(lineAndTime[1]);
				insertSqlStatement.parameters[':inclusiveTime'] = convertTime(uint(fileReader.getLine(5).slice(9)));
				insertSqlStatement.execute();
				executingSqlStatementAmount++;
								
				SqlUtil.execute('update tree set parent = ' + itemId + ' where parent = 0', sqlConnection);
				itemId++;
			
				fileReader.shiftCursor(10);
			}
			else
			{
				throw new Error('Unknown format or analyzer error');
			}
		}
		
		protected function convertTime(value:uint):uint
		{
			return uint(value / TIME_UNIT_IN_MS);
		}
		
		protected function createSqlStatement():SQLStatement
		{
			var statement:SQLStatement = new SQLStatement();
			statement.sqlConnection = sqlConnection;
			statement.addEventListener(SQLEvent.RESULT, handleSqlStatementResult);
			return statement;
		}
		
		protected function handleSqlStatementResult(event:SQLEvent):void
		{
			executingSqlStatementAmount--;
			checkComplete();
		}
		
		protected function checkComplete():void
		{
			if (fileReader == null && executingSqlStatementAmount == 0)
			{
				SqlUtil.execute('create index tree_parent on tree (parent)', sqlConnection);
				sqlConnection.addEventListener(SQLEvent.COMMIT, handleCommit);
				sqlConnection.commit();				
			}
		}
		
		protected function handleCommit(event:SQLEvent):void
		{
			sqlConnection.close();
			sqlConnection = null;
			dispatchEvent(new Event(Event.COMPLETE));
		}
	}
}