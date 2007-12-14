package develar.cachegrindVisualizer.parser
{
	import develar.cachegrindVisualizer.controls.tree.TreeItem;
	import develar.formatters.Formatter;
	import develar.utils.SqlUtil;
	
	import flash.data.SQLConnection;
	import flash.data.SQLMode;
	import flash.data.SQLStatement;
	import flash.data.SQLTransactionLockType;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.SQLErrorEvent;
	import flash.events.SQLEvent;
	import flash.filesystem.File;
	import flash.system.System;
	
	import mx.controls.Alert;
	
	public class DatabaseOpener extends EventDispatcher
	{
		internal static const MAIN_FUNCTION_ID:uint = 1;
		internal static const MAIN_FUNCTION_NAME:String = 'main';
		internal static const MAIN_FUNCTION_PATH:String = '';
		
		private static const SQLITE_CACHE_SIZE:uint = 200000; // около 300 МБ при весе страницы в 1,5 KB
				
		private static const INITIAL_DB_FILE_NAME:String = 'db.db';
		
		private var sqlConnection:SQLConnection;
		private var fileReader:FileReader;
		
		private var cursor:Cursor;
		
		private var timeBegin:Number;
		
		public function DatabaseOpener(file:File, sqlConnection:SQLConnection):void
		{
			this.sqlConnection = sqlConnection;
			
			mainTreeItem.id = MAIN_FUNCTION_ID;
			mainTreeItem.name = MAIN_FUNCTION_NAME;
			mainTreeItem.isBranch = true;
			mainTreeItem.path = MAIN_FUNCTION_PATH;
			
			fileReader = new FileReader(file);
			_db = File.applicationStorageDirectory.resolvePath(fileReader.checksum + '.db');
			
			sqlConnection.addEventListener(SQLErrorEvent.ERROR, handleError, false, 0, true);
		
			if (_db.exists)
			//if (false)
			{
				sqlConnection.addEventListener(SQLEvent.OPEN, handleOpenExistDb);
				sqlConnection.openAsync(db, SQLMode.READ);
			}
			else
			{	
				File.applicationDirectory.resolvePath(INITIAL_DB_FILE_NAME).copyTo(db, true);
							
				sqlConnection.addEventListener(SQLEvent.OPEN, handleOpenDb);
				sqlConnection.openAsync(db, SQLMode.UPDATE);
				
				cursor = new Cursor();
				cursor.mainTreeItem = mainTreeItem;
				cursor.insertStatement.sqlConnection = sqlConnection;
				
				fileReader.read();
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
		
		private function handleOpenExistDb(event:SQLEvent):void
		{
			sqlConnection.removeEventListener(SQLEvent.OPEN, handleOpenExistDb);
			
			var statement:SQLStatement = new SQLStatement();
			statement.sqlConnection = sqlConnection;						
			statement.text = 'select fileName from main.tree where path = :path';
			statement.parameters[':path'] = MAIN_FUNCTION_PATH;
			statement.addEventListener(SQLEvent.RESULT, handleSelectMainResult, false, 0, true);
			statement.execute();
		}
		
		private function handleSelectMainResult(event:SQLEvent):void
		{
			mainTreeItem.fileName = SQLStatement(event.target).getResult().data[0].fileName;
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		private function handleOpenDb(event:SQLEvent):void
		{
			sqlConnection.removeEventListener(SQLEvent.OPEN, handleOpenDb);
			
			sqlConnection.cacheSize = SQLITE_CACHE_SIZE;						
			sqlConnection.addEventListener(SQLEvent.BEGIN, handleBeginTransaction);
			sqlConnection.begin(SQLTransactionLockType.EXCLUSIVE);
		}
		
		private function handleBeginTransaction(event:SQLEvent):void
		{
			sqlConnection.removeEventListener(SQLEvent.BEGIN, handleBeginTransaction);			
			
			timeBegin = new Date().time;	
			parse();
		}
		
		private function parse():void
		{
			var parentId:uint = cursor.id++;
			var parser:AParser = new AParser(parentId, MAIN_FUNCTION_PATH, MAIN_FUNCTION_ID + '.' + parentId, fileReader, cursor);
			parser.addEventListener(Event.COMPLETE, handleParserComplete);			
		}
		
		private function handleParserComplete(event:Event):void
		{
			if (fileReader.complete)
			{
				var timeEnd:Number = new Date().time;
				trace('Затрачено на анализ: ' + ((timeEnd - timeBegin) / 1000) + '. Память: ' + Formatter.dataSize(System.totalMemory));
				SqlUtil.execute('create index tree_path on tree (path)', sqlConnection);
				SqlUtil.execute('create unique index tree_id on tree (id)', sqlConnection);
				
				sqlConnection.addEventListener(SQLEvent.COMMIT, handleCommit);
				sqlConnection.commit();				
			}
			else
			{
				parse();
			}
		}
		
		private function handleCommit(event:SQLEvent):void
		{
			sqlConnection.removeEventListener(SQLEvent.COMMIT, handleCommit);
			
			var timeEnd:Number = new Date().time;
			trace('Затрачено на анализ и создание индекса: ' + ((timeEnd - timeBegin) / 1000) + '. Память: ' + Formatter.dataSize(System.totalMemory));
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		private function handleError(event:SQLErrorEvent):void
		{
			 Alert.show(event.error.toString());
		}
	}
}