package develar.cachegrindVisualizer.parser
{	
	import develar.cachegrindVisualizer.controls.tree.TreeItem;
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
		
		protected var insertStatement:SQLStatement = new SQLStatement();
		protected var inclusiveTime:Object = new Object();
		protected var notInMainInclusiveTime:Number = 0;

		public function Parser(/*sqlConnection:SQLConnection, */file:File):void
		{
			_mainTreeItem.id = MAIN_FUNCTION_ID;
			_mainTreeItem.name = MAIN_FUNCTION_NAME;
			_mainTreeItem.isBranch = true;
			_mainTreeItem.path = MAIN_FUNCTION_PATH;
			
			sqlConnection = new SQLConnection(true);			
			
			fileReader = new FileReader(file);
			trace('память: ', Formatter.dataSize(System.totalMemory));
			_dbFile = File.applicationStorageDirectory.resolvePath(fileReader.checksum + '.db');			
			if (dbFile.exists)
			//if (false)
			{
				sqlConnection.addEventListener(SQLEvent.OPEN, handleOpenSqlConnectionToExistDb);
				sqlConnection.open(dbFile);
			}
			else
			{
				insertStatement.sqlConnection = sqlConnection;
				insertStatement.text = 'insert into main.tree (id, path, name, fileName, line, time, inclusiveTime) values (:id, :path, :name, :fileName, :line, :time, :inclusiveTime)';
							
				File.applicationResourceDirectory.resolvePath(INITIAL_DB_FILE_NAME).copyTo(dbFile, true);
				//sqlConnection.addEventListener(SQLEvent.OPEN, handleOpenSqlConnection);
				//sqlConnection.addEventListener(SQLEvent.COMMIT, handleCommit);
				sqlConnection.open(dbFile);
							
				fileReader.read();
				
				handleOpenSqlConnection();
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
		
		protected function handleOpenSqlConnection(/*event:SQLEvent*/):void
		{
			sqlConnection.begin(SQLTransactionLockType.EXCLUSIVE);
			
			// Деструкторы вне main, вызываются внутренним механизмом PHP
			while (!fileReader.complete)
			{
				var parentId:uint = itemId++;
				parseBody(parentId, MAIN_FUNCTION_PATH, MAIN_FUNCTION_ID + '.' + parentId);
			}
			
			fileReader = null;
			SqlUtil.execute('create index tree_path on tree (path)', sqlConnection);
			SqlUtil.execute('create unique index tree_id on tree (id)', sqlConnection);		
			sqlConnection.commit();	
			
			dispatchEvent(new Event(Event.COMPLETE));
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
					// деструкторы вне main, то есть сами по себе, и на данный момент inclusiveTime для него, естественно, не установлено
					if (_mainTreeItem.fileName == null && !(parentId in inclusiveTime))
					{
						notInMainInclusiveTime += inclusiveTime[parentId] = lineAndTime[1] / TIME_UNIT_IN_MS;
					}

					var fileName:String = fileReader.getLine(2); // не храним php:internal для экономии, - раз null, значит это php:internal
					insert(parentId, parentPath, fileReader.getLine(1).slice(3), fileName == 'fl=php:internal' ? null : fileName.slice(3), lineAndTime[0], lineAndTime[1]);
						
					fileReader.shiftCursor(4);
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
						insertParentItem(parentId, parentPath, sample, children);						
						// мы инкрементируем itemId при вызове parseBody в цикле чтения в handleOpenSqlConnection и строим от его предыдущего значения (это будет parentId для этого вызова parseBody) path. Если окажется, что вставка mainItem уже произошла, значит дети обрабатываемые в цикле внизу принадлежат не тому родителю, id которого мы сюда передали, а mainItem, следовательно мы должны изменить path (при этом id невставленного будущего, но несостоявшегосяя родителя пропадает, то есть будет лакуна) 
						if (_mainTreeItem.fileName != null && MAIN_FUNCTION_PATH == parentPath)
						{
							path = String(MAIN_FUNCTION_ID);
						}
											
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
			insertStatement.parameters[':id'] = id;
			insertStatement.parameters[':path'] = path;
			insertStatement.parameters[':name'] = name;			
			insertStatement.parameters[':fileName'] = fileName;
			insertStatement.parameters[':line'] = line;
			insertStatement.parameters[':time'] = time / TIME_UNIT_IN_MS;
			insertStatement.parameters[':inclusiveTime'] = inclusiveTime[id];
			
			insertStatement.execute();
			delete inclusiveTime[id];
		}
		
		protected function insertParentItem(id:uint, path:String, sample:String, children:Array):void
		{
			var lineAndTime:Array = fileReader.getLine(3).split(' ');
			
			if (sample == 'f')
			{
				// деструкторы вне main
				if (!(id in inclusiveTime))
				{
					var inclusiveTimeItem:Number = 0;
					inclusiveTime[id] = 0;
					for each (var childId:uint in children)
					{
						inclusiveTimeItem += inclusiveTime[childId];
					}
					notInMainInclusiveTime += inclusiveTime[id] = inclusiveTimeItem + (lineAndTime[1] / TIME_UNIT_IN_MS);
					
					path = String(MAIN_FUNCTION_ID);
				}
				insert(id, path, fileReader.getLine(4).slice(3), fileReader.getLine(5).slice(3), lineAndTime[0], lineAndTime[1]);
				fileReader.shiftCursor(7);
			}
			// для функции main не указывается файл, есть строка summary, отделенная пустыми строками
			else if (sample == '' || sample == 's')
			{
				var fileName:String = fileReader.getLine(8).slice(3);
				_mainTreeItem.fileName = fileName;				
				inclusiveTime[MAIN_FUNCTION_ID] = (Number(fileReader.getLine(5).slice(9)) / TIME_UNIT_IN_MS) + notInMainInclusiveTime;			
				
				insert(MAIN_FUNCTION_ID, path, MAIN_FUNCTION_NAME, fileName, lineAndTime[0], lineAndTime[1]);							
			
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