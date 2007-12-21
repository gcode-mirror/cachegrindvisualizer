package cachegrindVisualizer.parser
{	
	import develar.utils.SqlUtil;
	
	import flash.data.SQLConnection;
	import flash.data.SQLMode;
	import flash.data.SQLStatement;
	import flash.data.SQLTransactionLockType;
	import flash.events.EventDispatcher;
	import flash.filesystem.File;
	
	public class Parser extends EventDispatcher
	{		
		private static const MAIN_FUNCTION_NAME:String = 'main';
		
		private static const INITIAL_DB_FILE_NAME:String = 'db.db';
		/**
		 * Номер ревизии, в которой в последний раз была изменена заготовка БД
		 */
		private static const DB_VERSION:uint = 83;
		
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
		
		private var functionMap:FunctionMap;
		private var fileNameMap:FileNameMap;
		
		private var result:ParserResult = new ParserResult();	

		public function Parser(sqlConnection:SQLConnection):void
		{	
			this.sqlConnection = sqlConnection;
		}
		
		public function parse(file:File):ParserResult
		{
			fileReader = new FileReader(file);
			result.db = File.applicationStorageDirectory.resolvePath(DB_VERSION + '_' + fileReader.checksum + '.db');
			if (result.db.exists)
			//if (false)
			{				
				openExistDb();			
			}
			else
			{
				open();
			}
			
			return result;
		}
		
		private function openExistDb():void
		{
			sqlConnection.open(result.db, SQLMode.READ);
			var statement:SQLStatement = new SQLStatement();
			statement.sqlConnection = sqlConnection;				
			statement.text = 'select left, fileName from tree where right = :right and level = :level';
			statement.parameters[':right'] = 0;
			statement.parameters[':level'] = 0;
			statement.execute();
			
			var sqlResult:Object = statement.getResult().data[0];	
			result.mainTreeItem.left = sqlResult.left;
			result.mainTreeItem.fileName = sqlResult.fileName;
			
			functionMap = new FunctionMap(sqlConnection);
			functionMap.reload(true);
			result.names = functionMap.getArray();
			functionMap = null;
			
			fileNameMap = new FileNameMap(sqlConnection);
			fileNameMap.reload(true);
			result.fileNames = fileNameMap.getArray();
			fileNameMap = null;
			
			sqlConnection.close();
		}
		
		private function open():void
		{
			var timeBegin:Number = new Date().time;
			File.applicationDirectory.resolvePath(INITIAL_DB_FILE_NAME).copyTo(result.db, true);					
			sqlConnection.open(result.db, SQLMode.UPDATE);
			sqlConnection.cacheSize = SQL_CACHE_SIZE;
							
			insertStatement.sqlConnection = sqlConnection;
			insertStatement.text = 'insert into main.tree (left, right, level, name, fileName, line, time, inclusiveTime) values (:left, :right, :level, :name, :fileName, :line, :time, :inclusiveTime)';
				
			fileReader.read();
			
			sqlConnection.begin(SQLTransactionLockType.EXCLUSIVE);
			
			functionMap = new FunctionMap(sqlConnection);
			functionMap.addFunction("main");

			fileNameMap = new FileNameMap(sqlConnection);
			fileNameMap.addFile("");
			
			// Деструкторы вне main, вызываются внутренним механизмом PHP
			while (!fileReader.complete)
			{
				var parentId:uint = itemId++;
				parseBody(parentId, 1);
			}
			result.mainTreeItem.left = key + 1;

			functionMap.compact();
			fileNameMap.compact();

			functionMap.save();
			result.names = functionMap.getArray();
			functionMap = null;

			fileNameMap.save();
			result.fileNames = fileNameMap.getArray();
			fileNameMap = null;

			trace('Затрачено на анализ: ' + ((new Date().time - timeBegin) / 1000));			
			
			// если сначала создать индекс left, right, level, а потом inclusiveTime, то индексы будут битыми и в графе, в итоге, будет нарушена иерархия и имена
			SqlUtil.execute('create index tree_inclusiveTime on tree (inclusiveTime)', sqlConnection);
			SqlUtil.execute('create index tree_key on tree (left, right, level)', sqlConnection);
			
			trace('Затрачено на анализ и построение индекса: ' + ((new Date().time - timeBegin) / 1000));
			
			sqlConnection.close();
		}
						
		private function parseBody(parentId:uint, level:uint):void
		{				
			var children:Array = new Array();
			while (true)
			{					
				var lineAndTime:Array = fileReader.getLine(0).split(' ');				
				// нет детей
				if (fileReader.getLine(1).charAt(0) == 'f')
				{
					// деструкторы вне main, то есть сами по себе, и на данный момент inclusiveTime для него, естественно, не установлено
					if (result.mainTreeItem.fileName == 0 && !(parentId in inclusiveTime))
					{
						notInMainInclusiveTime += inclusiveTime[parentId] = lineAndTime[1] / TIME_UNIT_IN_MS;
					}

					insert(parentId, key--, level, getName(1), getFileName(2, true), lineAndTime[0], lineAndTime[1]);
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
		private function getEdge(id:uint, sample:String, children:Array, level:uint):Edge
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
					edge.level = 1;
					
					var inclusiveTimeItem:Number = 0;
					inclusiveTime[id] = 0;
					for each (var childId:uint in children)
					{
						inclusiveTimeItem += inclusiveTime[childId];
					}
					notInMainInclusiveTime += inclusiveTime[id] = inclusiveTimeItem + (lineAndTime[1] / TIME_UNIT_IN_MS);
				}			
				
				edge.right = key--;				
				edge.name = getName(4);
				edge.fileName = getFileName(5);				
				
				fileReader.shiftCursor(7);
			}
			// для функции main не указывается файл, есть строка summary, отделенная пустыми строками
			else if (sample == '' || sample == 's')
			{
				edge.right = 0;
				edge.level = 0;				
				edge.name = 0;
				edge.fileName = getFileName(8);
				
				result.mainTreeItem.fileName = edge.fileName;
				inclusiveTime[id] = (Number(fileReader.getLine(5).slice(9)) / TIME_UNIT_IN_MS) + notInMainInclusiveTime;				
				
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
				
		private function insert(id:uint, right:int, level:uint, name:uint, fileName:uint, line:uint, time:Number):void
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
		
		private function getName(offset:uint):uint
		{
			var name:String = fileReader.getLine(offset).slice(3);
			return functionMap.addFunction(name);
		}
		
		/**
		 * не храним php:internal для экономии, - раз null, значит это php:internal
		 */
		private function getFileName(offset:uint, checkOnInternal:Boolean = false):uint
		{			
			var fileName:String = fileReader.getLine(offset);
			if (checkOnInternal && fileName == 'fl=php:internal')
			{
				return 0;
			}
			else
			{
				fileName = fileName.slice(3);
				return fileNameMap.addFile(fileName);
			}
		}
	}
}