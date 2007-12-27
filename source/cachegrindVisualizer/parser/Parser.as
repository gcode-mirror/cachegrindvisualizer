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
		private static const FILE_NAME_TABLE:String = 'fileNames';	
		private static const FUNCTION_NAME_TABLE:String = 'names';	
		/**
		 * Номер ревизии, в которой в последний раз была изменена заготовка БД
		 */
		private static const DB_VERSION:uint = 98;
		
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
		
		private var functionNamesPathMap:NameMap;
		private var functionNameMap:NameMap;
		private var fileNameMap:NameMap;
		
		private var result:ParserResult = new ParserResult();	

		public function Parser(sqlConnection:SQLConnection):void
		{	
			this.sqlConnection = sqlConnection;
		}
		
		public function parse(file:File):ParserResult
		{
			functionNameMap = new NameMap(sqlConnection, FUNCTION_NAME_TABLE);
			fileNameMap = new NameMap(sqlConnection, FILE_NAME_TABLE);
			functionNamesPathMap = new NameMap();
			
			fileReader = new FileReader(file);
			result.db = File.applicationStorageDirectory.resolvePath(DB_VERSION + '_' + fileReader.checksum + '.db');
			//if (result.db.exists)
			if (false)
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
			
			result.names = functionNameMap.load();
			functionNameMap = null;
						
			result.fileNames = fileNameMap.load();
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
			insertStatement.text = 'insert into tree values (:left, :right, :level, :namesPath, :parentName, :name, :fileName, :line, :time, :inclusiveTime)';
				
			fileReader.read();
			
			sqlConnection.begin(SQLTransactionLockType.EXCLUSIVE);			
			
			functionNameMap.add(MAIN_FUNCTION_NAME);
			functionNamesPathMap.add('');
			fileNameMap.add('');
			
			// Деструкторы вне main, вызываются внутренним механизмом PHP
			while (!fileReader.complete)
			{
				var id:uint = itemId++;
				parseBody(id, '0', 0, 1);
			}
			result.mainTreeItem.left = key + 1;

			result.names = functionNameMap.save();
			functionNameMap = null;

			result.fileNames = fileNameMap.save();
			fileNameMap = null;

			trace('Затрачено на анализ: ' + ((new Date().time - timeBegin) / 1000));			
			
			// если сначала создать индекс left, right, level, а потом inclusiveTime, то индексы будут битыми и в графе, в итоге, будет нарушена иерархия и имена
			SqlUtil.execute('create index tree_inclusiveTime on tree (inclusiveTime)', sqlConnection);
			SqlUtil.execute('create index tree_key on tree (left, right, level)', sqlConnection);
			
			trace('Затрачено на анализ и построение индекса: ' + ((new Date().time - timeBegin) / 1000));
			
			sqlConnection.close();
		}
						
		private function parseBody(id:uint, namesPath:String, parentName:uint, level:uint):void
		{				
			var children:Array = new Array();
			while (true)
			{					
				var lineAndTime:Array = fileReader.getLine(0).split(' ');				
				// нет детей
				if (fileReader.getLine(1).charAt(0) == 'f')
				{
					// деструкторы вне main, то есть сами по себе, и на данный момент inclusiveTime для него, естественно, не установлено
					if (namesPath == '0')
					{
						notInMainInclusiveTime += inclusiveTime[id] = lineAndTime[1] / TIME_UNIT_IN_MS;
					}

					insert(id, key--, level, namesPath, parentName, getName(1), getFileName(2, true), lineAndTime[0], lineAndTime[1]);
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
						var edge:Edge = getEdge(id, sample, children, level);
						for each (var childId:uint in children)
						{
							parseBody(childId, namesPath + '.' + edge.name, edge.name, edge.level + 1);
						}						
						insert(id, edge.right, edge.level, namesPath, parentName, edge.name, edge.fileName, edge.line, edge.time);																		
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
				
		private function insert(id:uint, right:int, level:uint, namesPath:String, parentName:uint, name:uint, fileName:uint, line:uint, time:Number):void
		{
			insertStatement.parameters[':left'] = key--;
			insertStatement.parameters[':right'] = right;			
			insertStatement.parameters[':level'] = level;
			insertStatement.parameters[':parentName'] = parentName;
			insertStatement.parameters[':namesPath'] = functionNamesPathMap.add(namesPath + '.' + name);
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
			return functionNameMap.add(fileReader.getLine(offset).slice(3));
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
				return fileNameMap.add(fileName);
			}
		}
	}
}