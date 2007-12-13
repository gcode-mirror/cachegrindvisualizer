package develar.cachegrindVisualizer.parser
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.SQLEvent;
		
	internal class AParser extends EventDispatcher
	{		
		/**
		 * Курс преобразования стоимости в милисекунды
		 */	
		private static const TIME_UNIT_IN_MS:uint = 10000;
		
		private var fileReader:FileReader;
		private var cursor:Cursor;	
		
		private var id:uint;
		private var path:String;
		private var childPath:String;
		
		private var children:Array = new Array();
		
		public function AParser(id:uint, path:String, childPath:String, fileReader:FileReader, cursor:Cursor):void
		{
			this.id = id;
			this.path = path;
			this.childPath = childPath;
			
			this.fileReader = fileReader;
			this.cursor = cursor;
			
			parse();
		}
		
		private function parse():void
		{
			var lineAndTime:Array = fileReader.getLine(0).split(' ');
			// нет детей
			if (fileReader.getLine(1).charAt(0) == 'f')
			{
				// деструкторы вне main, то есть сами по себе, и на данный момент inclusiveTime для него, естественно, не установлено
				if (cursor.mainTreeItem.fileName == null && !(id in cursor.inclusiveTime))
				{
					//notInMainInclusiveTime += cursor.inclusiveTime[parentId] = lineAndTime[1] / TIME_UNIT_IN_MS;
				}
	
				var fileName:String = fileReader.getLine(2); // не храним php:internal для экономии, - раз null, значит это php:internal				
				insert(fileReader.getLine(1).slice(3), fileName == 'fl=php:internal' ? null : fileName.slice(3), lineAndTime[0], lineAndTime[1], 4);
			}
			else
			{
				// вставка сразу невозможна, так как мы не знаем всех данных, а потом придется обновлять - в 2 раза больше запросов и необходимость индекса на поле id			
				cursor.inclusiveTime[cursor.id] = lineAndTime[1] / TIME_UNIT_IN_MS;			
				children.push(cursor.id++);
				
				var sample:String = fileReader.getLine(4).charAt(0);
				// следующий ребенок (cfn)
				if (sample == 'c')
				{
					fileReader.shiftCursor(3);
					parse();
				}
				// данные о родителе после всех детей
				else
				{
					insertParentItem(sample);
				}
			}
		}
		
		private function insertParentItem(sample:String):void
		{
			var lineAndTime:Array = fileReader.getLine(3).split(' ');			
			if (sample == 'f')
			{
				// деструкторы вне main
				if (!(id in cursor.inclusiveTime))
				{
					var inclusiveTimeItem:Number = 0;
					cursor.inclusiveTime[id] = 0;
					for each (var childId:uint in children)
					{
						inclusiveTimeItem += cursor.inclusiveTime[childId];
					}
					//notInMainInclusiveTime += inclusiveTime[id] = inclusiveTimeItem + (lineAndTime[1] / TIME_UNIT_IN_MS);
					
					path = String(DatabaseOpener.MAIN_FUNCTION_ID);
				}
				
				insert(fileReader.getLine(4).slice(3), fileReader.getLine(5).slice(3), lineAndTime[0], lineAndTime[1], 7);				
			}
			// для функции main не указывается файл, есть строка summary, отделенная пустыми строками
			else if (sample == '' || sample == 's')
			{
				var fileName:String = fileReader.getLine(8).slice(3);
				cursor.mainTreeItem.fileName = fileName;				
				cursor.inclusiveTime[DatabaseOpener.MAIN_FUNCTION_ID] = (Number(fileReader.getLine(5).slice(9)) / TIME_UNIT_IN_MS)/* + notInMainInclusiveTime*/;
				
				childPath = String(DatabaseOpener.MAIN_FUNCTION_ID);
				
				id = DatabaseOpener.MAIN_FUNCTION_ID;
				insert(DatabaseOpener.MAIN_FUNCTION_NAME, fileName, lineAndTime[0], lineAndTime[1], 10);
			}
			else
			{
				throw new Error('Unknown format or parser error');
			}
		}
		
		/**
		 * Мы не передаем массив lineAndTime вместо 2 параметров line и time для типизации
		 */
		protected function insert(name:String, fileName:String, line:uint, time:Number, cursorOffset:uint):void
		{
			fileReader.shiftCursor(cursorOffset);
			
			cursor.insertStatement.parameters[':id'] = id;
			cursor.insertStatement.parameters[':path'] = path;
			cursor.insertStatement.parameters[':name'] = name;			
			cursor.insertStatement.parameters[':fileName'] = fileName;
			cursor.insertStatement.parameters[':line'] = line;
			cursor.insertStatement.parameters[':time'] = time / TIME_UNIT_IN_MS;
			cursor.insertStatement.parameters[':inclusiveTime'] = cursor.inclusiveTime[id];
			
			cursor.insertStatement.addEventListener(SQLEvent.RESULT, handleInsert);			
			cursor.insertStatement.execute();
			delete cursor.inclusiveTime[id];
		}
		
		protected function handleInsert(event:SQLEvent):void
		{
			cursor.insertStatement.removeEventListener(SQLEvent.RESULT, handleInsert);
			handleComplete();
		}
		
		private function handleComplete(event:Event = null):void
		{			
			if (children.length > 0)
			{
				var childId:uint = children.shift();
				var parser:AParser = new AParser(childId, childPath, childPath + '.' + childId, fileReader, cursor);
				parser.addEventListener(Event.COMPLETE, handleComplete);
			}
			else
			{
				dispatchEvent(new Event(Event.COMPLETE));
			}
		}
	}
}