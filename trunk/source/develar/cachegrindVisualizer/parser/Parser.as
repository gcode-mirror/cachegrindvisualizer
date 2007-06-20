package develar.cachegrindVisualizer.parser
{	
	import flash.system.System;	
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.utils.ByteArray;
	import flash.filesystem.FileStream;	
	import flash.data.SQLConnection;
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
		protected var itemId:Number = 0;
		protected var fileReader:FileReader;
		
		protected var insertSQLStatement:SQLStatement = new SQLStatement();
		
		protected var _sqlConnection:SQLConnection = new SQLConnection();
		public function get sqlConnection():SQLConnection
		{
			return _sqlConnection;
		}
			
		public function Parser(file:File):void
		{
			fileReader = new FileReader(file);
			trace('память: ', Formatter.dataSize(System.totalMemory));
			var dbFile:File = File.applicationStorageDirectory.resolve(fileReader.checksum + '.db');			
			if (/*dbFile.exists*/false)
			{
				sqlConnection.open(dbFile);
			}
			else
			{
				File.applicationResourceDirectory.resolve(INITIAL_DB_FILE_NAME).copyTo(dbFile, true);
				sqlConnection.addEventListener(SQLEvent.OPEN, handleOpenSqlConnection);
				sqlConnection.open(dbFile);
				
				var fileStream:FileStream = new FileStream();
				fileStream.open(file, FileMode.READ);
				
				fileReader.read();
				
				
				parse();
			}
		}
		
		protected function handleOpenSqlConnection(event:SQLEvent):void
		{
			insertSQLStatement.text = 'insert into tree values (null, :parent, :name, :fileName, :line, :time, :inclusiveTime)';
			insertSQLStatement.sqlConnection = sqlConnection;
			insertSQLStatement.addEventListener(SQLEvent.PREPARE, handleInsertSQLStatementPrepare);
			insertSQLStatement.addEventListener(SQLErrorEvent.ERROR, handleError);
			insertSQLStatement.prepare();
		}
		
		protected function handleError(event:SQLErrorEvent):void
		{
			
		}
		
		protected function handleInsertSQLStatementPrepare(event:SQLEvent):void
		{
			/*insertSQLStatement.parameters[':parent'] = 0;
			insertSQLStatement.parameters[':name'] = 'jhj';
			insertSQLStatement.parameters[':fileName'] = 'ffsfsdf';
			insertSQLStatement.parameters[':line'] = 43;
			insertSQLStatement.parameters[':time'] = 8556;
			insertSQLStatement.parameters[':inclusiveTime'] = 2222222;
			insertSQLStatement.execute();*/
		}
		
		protected function parse():Item
		{
			cursor = fileReader.data.length - 1;	
				
			var result:Array = new Array();
			while (cursor > 4)
			{
				result.unshift(new Item());
				parseBody(result[0]);
			}
			
			fileReader = null;
			
			var result_length:uint = result.length;
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
			}
			
			return result[0];
		}
				
		private function parseBody(parent:Item):void
		{				
			var children:Array = new Array();
			while (true)
			{					
				var line_and_time:Array = fileReader.data[cursor].split(' ');				
				// нет детей
				if (fileReader.data[cursor - 1].charAt(0) == 'f')
				{
					parent.time = line_and_time[1] / TIME_UNIT_IN_MS;
					parent.name = fileReader.data[cursor - 1].slice(3);					
					var fileName:String = fileReader.data[cursor - 2];
					if (fileName != 'fl=php:internal')
					{
						parent.fileName = fileName.slice(3);
					}
					
					cursor -= 4;
					break;
				}
				else
				{
					insertSQLStatement.parameters[':parent'] = 0;
					insertSQLStatement.parameters[':name'] = fileReader.data[cursor - 2].slice(4);
					insertSQLStatement.parameters[':fileName'] = 'ffsfsdf';
					insertSQLStatement.parameters[':line'] = line_and_time[0];
					insertSQLStatement.parameters[':time'] = 8556;
					insertSQLStatement.parameters[':inclusiveTime'] = line_and_time[1] / TIME_UNIT_IN_MS;
					insertSQLStatement.execute();
			
					var child:Item = new Item();
					//child.name = fileReader.data[cursor - 2].slice(4);
					//child.line = line_and_time[0];
					//child.inclusiveTime = line_and_time[1] / TIME_UNIT_IN_MS;
					children.unshift(itemId);
					itemId++;
		
					var sample:String = fileReader.data[cursor - 4].charAt(0);
					// следующий ребенок (cfn)
					if (sample == 'c')
					{
						cursor -= 3;
					}
					// данные о родителе после всех детей
					else
					{
						line_and_time = fileReader.data[cursor - 3].split(' ');						
						parent.time = line_and_time[1] / TIME_UNIT_IN_MS;
						
						if (sample == 'f')
						{
							parent.name = fileReader.data[cursor - 4].slice(3);
							parent.fileName = fileReader.data[cursor - 5].slice(3);
							cursor -= 7;		
						}
						// для функции main не указывается файл, есть строка summary, отделенная пустыми строками
						else if (sample == '' || sample == 's')
						{
							parent.name = MAIN_FUNCTION_NAME;
							parent.fileName = fileReader.data[cursor - 8].slice(3);
							parent.inclusiveTime = fileReader.data[cursor - 5].slice(9) / TIME_UNIT_IN_MS;
							
							cursor -= 10;
						}
						else
						{
							throw new Error('Unknown format or analyzer error');
						}
		
						parent.children = children;
						for (var childIndex:int = children.length - 1; childIndex > -1; childIndex--)
						{
							parseBody(children[childIndex]);
						}
												
						break;
					}
				}
			}
		}
	}
}