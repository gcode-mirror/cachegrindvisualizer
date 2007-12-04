package develar.cachegrindVisualizer.parser
{	
	import develar.cachegrindVisualizer.controls.tree.TreeItem;
	import develar.formatters.Formatter;
	import develar.utils.SqlUtil;
	
	import flash.data.SQLConnection;
	import flash.data.SQLResult;
	import flash.data.SQLStatement;
	import flash.data.SQLTransactionLockType;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.SQLErrorEvent;
	import flash.events.SQLEvent;
	import flash.filesystem.File;
	import flash.system.System;
	
	public class Parser extends EventDispatcher
	{
		public static const MAIN_FUNCTION_ID:uint = 1;
		protected static const MAIN_FUNCTION_NAME:String = 'main';
		protected static const MAIN_FUNCTION_PATH:String = '';		
		protected static const INITIAL_DB_FILE_NAME:String = 'db.db';		

		/**
		 * Курс преобразования стоимости в милисекунды
		 */	
		protected static const TIME_UNIT_IN_MS:uint = 10000;
				
		protected var itemId:uint = MAIN_FUNCTION_ID + 1;
		protected var sqlConnection:SQLConnection;
		protected var fileReader:FileReader;
		
		protected var inclusiveTime:Object = new Object();

		public function Parser(sqlConnection:SQLConnection, file:File):void
		{
			_mainTreeItem.id = MAIN_FUNCTION_ID;
			_mainTreeItem.name = MAIN_FUNCTION_NAME;
			_mainTreeItem.isBranch = true;
			_mainTreeItem.path = MAIN_FUNCTION_PATH;
			
			this.sqlConnection = sqlConnection;
			
			fileReader = new FileReader(file);
			trace('память: ', Formatter.dataSize(System.totalMemory));
			_dbFile = File.applicationStorageDirectory.resolvePath(fileReader.checksum + '.db');			
			if (dbFile.exists/*false*/)
			{
				sqlConnection.addEventListener(SQLEvent.OPEN, handleOpenSqlConnectionToExistDb);
				sqlConnection.open(dbFile);				
			}
			else
			{				
				File.applicationResourceDirectory.resolvePath(INITIAL_DB_FILE_NAME).copyTo(dbFile, true);
				sqlConnection.addEventListener(SQLEvent.OPEN, handleOpenSqlConnection);
				sqlConnection.addEventListener(SQLEvent.COMMIT, handleCommit);
				sqlConnection.open(dbFile);
							
				fileReader.read();
			}
		}
		
		protected var _mainTreeItem:TreeItem = new TreeItem();
		public function get mainTreeItem():TreeItem 
		{
			return _mainTreeItem;
		}
		
		protected var _dbFile:File;
		public function get dbFile():File
		{
			return _dbFile;
		}
		
		protected function handleOpenSqlConnection(event:SQLEvent):void
		{
			sqlConnection.begin(SQLTransactionLockType.EXCLUSIVE);
			
			parseBody(MAIN_FUNCTION_ID, MAIN_FUNCTION_PATH, String(MAIN_FUNCTION_ID));
			
			fileReader = null;
			SqlUtil.execute('create index tree_path on tree (path)', sqlConnection);
			SqlUtil.execute('create unique index tree_id on tree (id)', sqlConnection);		
			sqlConnection.commit();	
		}
		
		protected function handleOpenSqlConnectionToExistDb(event:SQLEvent):void
		{
			var statement:SQLStatement = new SQLStatement();
			statement.sqlConnection = sqlConnection;
			statement.addEventListener(SQLEvent.RESULT, handleSelectMainTreeItem);					
			statement.text = 'select fileName from main.tree where path = :path';
			statement.parameters[':path'] = MAIN_FUNCTION_PATH;
			statement.execute();
		}
		
		protected function handleSelectMainTreeItem(event:SQLEvent):void
		{
			_mainTreeItem.fileName = SQLStatement(event.target).getResult().data[0].fileName;
			
			dispatchEvent(new Event(Event.COMPLETE));
		}
				
		protected function parseBody(parentId:uint, parentPath:String, path:String):void
		{				
			var children:Array = new Array();
			while (true)
			{					
				var lineAndTime:Array = fileReader.getLine(0).split(' ');				
				// нет детей
				if (fileReader.getLine(1).charAt(0) == 'f')
				{
					// деструкторы вне main, то есть сами по себе
					if (parentId == 1)
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
						var fileName:String = fileReader.getLine(2); // не храним php:internal для экономии, - раз null, значит это php:internal
						insert(parentId, parentPath, fileReader.getLine(1).slice(3), fileName == 'fl=php:internal' ? null : fileName.slice(3), lineAndTime[0], lineAndTime[1]);
						
						fileReader.shiftCursor(4);						
					}
					break;
				}
				else
				{
					// вставка сразу невозможна, так как мы не знаем всех данных, а потом придется обновлять - в 2 раза больше запросов и необходимость индекса на поле id			
					inclusiveTime[itemId] = lineAndTime[1] / TIME_UNIT_IN_MS;			
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
						insertParentItem(parentId, parentPath, sample);								
						for each (var childId:uint in children)
						{
							parseBody(childId, path, path + '.' + childId);
						}												
						break;
					}
				}
			}
		}
		
		/**
		 * Мы не передаем массив lineAndTime вместо 2 параметров line и time для типизации
		 */
		protected function insert(id:uint, path:String, name:String, fileName:String, line:uint, time:Number):void
		{	
			var statement:SQLStatement = new SQLStatement();
			statement.sqlConnection = sqlConnection;					
			statement.text = 'insert into main.tree (id, path, name, fileName, line, time, inclusiveTime) values (:id, :path, :name, :fileName, :line, round(:time, 1), round(:inclusiveTime, 1))';
			statement.parameters[':id'] = id;
			statement.parameters[':path'] = path;
			statement.parameters[':name'] = name;			
			statement.parameters[':fileName'] = fileName;
			statement.parameters[':line'] = line;
			statement.parameters[':time'] = time / TIME_UNIT_IN_MS;
			statement.parameters[':inclusiveTime'] = inclusiveTime[id];
			
			statement.addEventListener(SQLErrorEvent.ERROR, handleSqlError);
			statement.execute();		
			delete inclusiveTime[id];
		}
		
		protected function handleSqlError(event:SQLErrorEvent):void
		{
			
		}
		
		protected function insertParentItem(id:uint, path:String, sample:String):void
		{
			var lineAndTime:Array = fileReader.getLine(3).split(' ');
			
			if (sample == 'f')
			{
				/*if (id != 1)
				{*/
					insert(id, path, fileReader.getLine(4).slice(3), fileReader.getLine(5).slice(3), lineAndTime[0], lineAndTime[1]);				
				//}
				fileReader.shiftCursor(7);
			}
			// для функции main не указывается файл, есть строка summary, отделенная пустыми строками
			else if (sample == '' || sample == 's')
			{
				var fileName:String = fileReader.getLine(8).slice(3);
				_mainTreeItem.fileName = fileName;				
				inclusiveTime[id] = Number(fileReader.getLine(5).slice(9)) / TIME_UNIT_IN_MS;			
				
				insert(id, path, MAIN_FUNCTION_NAME, fileName, lineAndTime[0], lineAndTime[1]);							
			
				fileReader.shiftCursor(10);
			}
			else
			{
				throw new Error('Unknown format or analyzer error');
			}
		}
		
		protected function handleCommit(event:SQLEvent):void
		{			
			dispatchEvent(new Event(Event.COMPLETE));	
		}
	}
}