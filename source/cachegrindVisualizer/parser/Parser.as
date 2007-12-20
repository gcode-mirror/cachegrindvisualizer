package cachegrindVisualizer.parser
{	
	import cachegrindVisualizer.controls.tree.TreeItem;
	
	import develar.utils.SqlUtil;
	
	import flash.data.SQLConnection;
	import flash.data.SQLMode;
	import flash.data.SQLStatement;
	import flash.data.SQLTransactionLockType;
	import flash.events.EventDispatcher;
	import flash.filesystem.File;
	
	public class Parser extends EventDispatcher
	{
		public static const MAIN_FUNCTION_LEVEL:uint = 0;
		private static const MAIN_FUNCTION_RIGHT:int = 0;
		private static const MAIN_FUNCTION_NAME:String = 'main';		
		private static const INITIAL_DB_FILE_NAME:String = 'db.db';
		
		private static const SQL_CACHE_SIZE:uint = 200000;

		/**
		 * Курс преобразования стоимости в милисекунды
		 */	
		private static const TIME_UNIT_IN_MS:uint = 1000;
				
		private var itemId:uint;
		private var fileReader:FileReader;
		private var sqlConnection:SQLConnection;
		
		private var insertStatement:SQLStatement = new SQLStatement();
		private var inclusiveTime:Object = new Object();
		private var notInMainInclusiveTime:Number = 0;		
		private var key:int = -1; // 0 для main

		public function Parser(file:File, sqlConnection:SQLConnection):void
		{	
			this.sqlConnection = sqlConnection;
					
			mainTreeItem.right = MAIN_FUNCTION_RIGHT;
			mainTreeItem.level = MAIN_FUNCTION_LEVEL;
			mainTreeItem.name = MAIN_FUNCTION_NAME;			
			mainTreeItem.isBranch = true;
			
			fileReader = new FileReader(file);
			_db = File.applicationStorageDirectory.resolvePath(fileReader.checksum + '.db');
			if (db.exists)
			//if (false)
			{				
				openExistDb();			
			}
			else
			{
				open();
			}
		}
		
		private var _mainTreeItem:TreeItem = new TreeItem();
		public function get mainTreeItem():TreeItem 
		{
			return _mainTreeItem;
		}
		
		private var _db:File;
		public function get db():File 
		{
			return _db;
		}
		
		protected function openExistDb():void
		{
			sqlConnection.open(db, SQLMode.READ);
			var statement:SQLStatement = new SQLStatement();
			statement.sqlConnection = sqlConnection;				
			statement.text = 'select left, fileName from main.tree where right = :right and level = :level';
			statement.parameters[':right'] = MAIN_FUNCTION_RIGHT;
			statement.parameters[':level'] = MAIN_FUNCTION_LEVEL;
			statement.execute();
			
			var result:Object = statement.getResult().data[0];	
			mainTreeItem.left = result.left;
			mainTreeItem.fileName = result.fileName;			
			
			sqlConnection.close();
		}
		
		protected function open():void
		{
			var timeBegin:Number = new Date().time;
			File.applicationDirectory.resolvePath(INITIAL_DB_FILE_NAME).copyTo(db, true);					
			sqlConnection.open(db, SQLMode.UPDATE);
			sqlConnection.cacheSize = SQL_CACHE_SIZE;
							
			insertStatement.sqlConnection = sqlConnection;
			insertStatement.text = 'insert into main.tree (left, right, level, name, fileName, line, time, inclusiveTime) values (:left, :right, :level, :name, :fileName, :line, :time, :inclusiveTime)';
				
			fileReader.read();
			
			sqlConnection.begin(SQLTransactionLockType.EXCLUSIVE);
			
			// Деструкторы вне main, вызываются внутренним механизмом PHP
			while (!fileReader.complete)
			{
				var parentId:uint = itemId++;
				parseBody(parentId, MAIN_FUNCTION_LEVEL + 1);
			}
			mainTreeItem.left = key + 1;
			
			trace('Затрачено на анализ: ' + ((new Date().time - timeBegin) / 1000));			
			
			// если сначала создать индекс left, right, level, а потом inclusiveTime, то индексы будут битыми и в графе, в итоге, будет нарушена иерархия и имена
			SqlUtil.execute('create index tree_inclusiveTime on tree (inclusiveTime)', sqlConnection);
			SqlUtil.execute('create index tree_key on tree (left, right, level)', sqlConnection);
			
			trace('Затрачено на анализ и построение индекса: ' + ((new Date().time - timeBegin) / 1000));
			
			sqlConnection.close();
		}
				
		protected function parseBody(parentId:uint, level:uint):void
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
					insert(parentId, key--, level, fileReader.getLine(1).slice(3), fileName == 'fl=php:internal' ? null : fileName.slice(3), lineAndTime[0], lineAndTime[1]);
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
						var edge:Edge = getEdge(parentId, sample, children, level);
						for each (var childId:uint in children)
						{
							parseBody(childId, edge.level + 1);
						}						
						insert(parentId, edge.right, edge.level, edge.name, edge.fileName, edge.line, edge.time);																		
						break;
					}
				}
			}
		}
		
		/**
		 * Edge содержит right и level для их корректировки в случае main (xdebug пишет деструкторы вне main, мы это исправляем)
		 */
		protected function getEdge(id:uint, sample:String, children:Array, level:uint):Edge
		{
			var lineAndTime:Array = fileReader.getLine(3).split(' ');
			var edge:Edge = new Edge();
			if (sample == 'f')
			{
				// деструкторы вне main
				if (id in inclusiveTime)
				{
					edge.level = level;
				}
				else
				{
					edge.level = MAIN_FUNCTION_LEVEL + 1;
					
					var inclusiveTimeItem:Number = 0;
					inclusiveTime[id] = 0;
					for each (var childId:uint in children)
					{
						inclusiveTimeItem += inclusiveTime[childId];
					}
					notInMainInclusiveTime += inclusiveTime[id] = inclusiveTimeItem + (lineAndTime[1] / TIME_UNIT_IN_MS);
				}			
				
				edge.right = key--;
				
				edge.name = fileReader.getLine(4).slice(3);
				edge.fileName = fileReader.getLine(5).slice(3);				
				
				fileReader.shiftCursor(7);
			}
			// для функции main не указывается файл, есть строка summary, отделенная пустыми строками
			else if (sample == '' || sample == 's')
			{
				var fileName:String = fileReader.getLine(8).slice(3);
				_mainTreeItem.fileName = fileName;				
				inclusiveTime[id] = (Number(fileReader.getLine(5).slice(9)) / TIME_UNIT_IN_MS) + notInMainInclusiveTime;			
				
				edge.right = MAIN_FUNCTION_RIGHT;
				edge.level = MAIN_FUNCTION_LEVEL;
				
				edge.name = MAIN_FUNCTION_NAME;
				edge.fileName = fileReader.getLine(8).slice(3);
				
				fileReader.shiftCursor(10);
			}
			else
			{
				throw new Error('Unknown format or analyzer error');
			}
			
			edge.line = lineAndTime[0];
			edge.time = lineAndTime[1];
			return edge;
		}
				
		protected function insert(id:uint, right:int, level:uint, name:String, fileName:String, line:uint, time:Number):void
		{
			insertStatement.parameters[':left'] = key--;
			insertStatement.parameters[':right'] = right;			
			insertStatement.parameters[':level'] = level;
			insertStatement.parameters[':name'] = name;			
			insertStatement.parameters[':fileName'] = fileName;
			insertStatement.parameters[':line'] = line;
			insertStatement.parameters[':time'] = time / TIME_UNIT_IN_MS;
			insertStatement.parameters[':inclusiveTime'] = inclusiveTime[id];
			
			insertStatement.execute();
			delete inclusiveTime[id];
		}
	}
}