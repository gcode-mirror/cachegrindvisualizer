package develar.cachegrindVisualizer
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
	import develar.encryption.Sha1;
	
	public class Parser
	{
		public static const MAIN_FUNCTION_NAME:String = 'main';
		
		protected static const INITIAL_DB_FILE_NAME:String = 'db.db';		
		/**
		 * Сколько байт данных обрабатывать за одно чтение
		 */
		protected static const DATA_PORTION_LENGTH:uint = 10485760; // 10 МБ		
		/**
		 * Длина строки для расчета контрольной суммы (1 с начала, другая с середины)
		 */
		protected static const CHECK_STRING_LENGTH:uint = 512;		
		/**
		 * Длина строки для определения символа разделителя строк (первая строка это версия - version: 0.9.6, поэтому 20 вполне хватит)
		 */
		protected static const TEST_STRING_LENGTH:uint = 20;
		/**
		 * Курс преобразования стоимости в милисекунды
		 */	
		protected static const TIME_UNIT_IN_MS:uint = 10000;		
		
		protected var data:Array;		
		protected var cursor:uint = 0;
		
		protected var lineEnding:String;
		
		protected var insertSQLStatement:SQLStatement = new SQLStatement();
		
		protected var _sqlConnection:SQLConnection = new SQLConnection();
		public function get sqlConnection():SQLConnection
		{
			return _sqlConnection;
		}
			
		public function Parser(file:File):void
		{
			var dbFile:File = File.applicationStorageDirectory.resolve(calculateChecksum(file) + '.db');			
			if (dbFile.exists)
			{
				sqlConnection.open(dbFile);
			}
			else
			{
				File.applicationResourceDirectory.resolve(INITIAL_DB_FILE_NAME).copyTo(dbFile);
				sqlConnection.addEventListener(SQLEvent.OPEN, handleOpenSqlConnection);
				sqlConnection.open(dbFile);
				
				var fileStream:FileStream = new FileStream();
				fileStream.open(file, FileMode.READ);
				
				var length:Number = DATA_PORTION_LENGTH;
				if (length > fileStream.bytesAvailable)
				{
					length = fileStream.bytesAvailable;
				}
				data = fileStream.readUTFBytes(length).split(lineEnding);
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
			insertSQLStatement.parameters[':parent'] = 0;
			insertSQLStatement.parameters[':name'] = 'jhj';
			insertSQLStatement.parameters[':fileName'] = 'ffsfsdf';
			insertSQLStatement.parameters[':line'] = 43;
			insertSQLStatement.parameters[':time'] = 8556;
			insertSQLStatement.parameters[':inclusiveTime'] = 2222222;
			insertSQLStatement.execute();
		}
		
		protected function calculateChecksum(file:File):String
		{
			var fileStream:FileStream = new FileStream();
			fileStream.open(file, FileMode.READ);
			
			var checksum:String = fileStream.readUTFBytes(CHECK_STRING_LENGTH);
			fileStream.position = fileStream.bytesAvailable / 2;
			checksum += fileStream.readUTFBytes(CHECK_STRING_LENGTH);
			
			lineEnding = checksum.slice(0, TEST_STRING_LENGTH).search('\r\n') == -1 ? '\n' : '\r\n';
			
			checksum = Sha1.hashHmac(checksum, String(fileStream.bytesAvailable));
			return checksum;
		}
		
		public function parse():Item
		{
			// 2 пустых строки + 1 для установки именно на позицию
			cursor = this.data.length - 3;	
				
			var result:Array = new Array();
			while (cursor > 4)
			{
				result.unshift(new Item());
				parseBody(result[0]);
			}
			
			this.data = null;
			
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
				var line_and_time:Array = data[cursor].split(' ');				
				// нет детей
				if (data[cursor - 1].charAt(0) == 'f')
				{
					parent.time = line_and_time[1] / TIME_UNIT_IN_MS;
					parent.name = data[cursor - 1].slice(3);					
					var fileName:String = data[cursor - 2];
					if (fileName != 'fl=php:internal')
					{
						parent.fileName = fileName.slice(3);
					}
					
					cursor -= 4;
					break;
				}
				else
				{
					var child:Item = new Item();
					child.name = data[cursor - 2].slice(4);
					child.line = line_and_time[0];
					child.inclusiveTime = line_and_time[1] / TIME_UNIT_IN_MS;
					children.unshift(child);
		
					var sample:String = data[cursor - 4].charAt(0);
					// следующий ребенок (cfn)
					if (sample == 'c')
					{
						cursor -= 3;
					}
					// данные о родителе после всех детей
					else
					{
						line_and_time = data[cursor - 3].split(' ');						
						parent.time = line_and_time[1] / TIME_UNIT_IN_MS;
						
						if (sample == 'f')
						{
							parent.name = data[cursor - 4].slice(3);
							parent.fileName = data[cursor - 5].slice(3);
							cursor -= 7;		
						}
						// для функции main не указывается файл, есть строка summary, отделенная пустыми строками
						else if (sample == '' || sample == 's')
						{
							parent.name = MAIN_FUNCTION_NAME;
							parent.fileName = data[cursor - 8].slice(3);
							parent.inclusiveTime = data[cursor - 5].slice(9) / TIME_UNIT_IN_MS;
							
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