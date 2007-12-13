package develar.cachegrindVisualizer.parser
{
	import develar.cachegrindVisualizer.controls.tree.TreeItem;
	
	import flash.data.SQLConnection;
	import flash.data.SQLMode;
	import flash.data.SQLStatement;
	import flash.data.SQLTransactionLockType;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.SQLEvent;
	import flash.filesystem.File;
	
	import develar.utils.SqlUtil;
	
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
		
		public function DatabaseOpener(file:File, sqlConnection:SQLConnection):void
		{
			this.sqlConnection = sqlConnection;
			
			fileReader = new FileReader(file);
			_db = File.applicationStorageDirectory.resolvePath(fileReader.checksum + '.db');
			//if (dbFile.exists)
			if (false)
			{
				sqlConnection.addEventListener(SQLEvent.OPEN, handleOpenExistDb);
				sqlConnection.openAsync(db, SQLMode.READ);
			}
			else
			{	
				File.applicationDirectory.resolvePath(INITIAL_DB_FILE_NAME).copyTo(db, true);
							
				sqlConnection.addEventListener(SQLEvent.OPEN, handleOpenDb);
				sqlConnection.openAsync(db, SQLMode.UPDATE, null, false, 4096);
				
				cursor = new Cursor();
				cursor.insertStatement.sqlConnection = sqlConnection;
				
				fileReader.read();
			}
		}
		
		public function get mainTreeItem():TreeItem 
		{
			return cursor.mainTreeItem;
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
			
			dispatchEvent(new Event(Event.COMPLETE));
		}
	}
}