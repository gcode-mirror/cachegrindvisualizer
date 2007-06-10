package develar.cachegrindVisualizer
{	
	import flash.system.System;
	import develar.formatters.Formatter;
	
	public class Parser
	{
		public static const MAIN_FUNCTION_NAME:String = 'main';
		
		/**
		 * Длина строки для определения символа разделителя строк (первая строка это версия - version: 0.9.6, поэтому 20 вполне хватит)
		 */
		protected static const TEST_STRING_LENGTH:uint = 20;		
		protected static const TIME_UNIT_IN_MS:uint = 10000;		
		
		protected var data:Array;
		
		protected var _result:Item = new Item();
		public function get result():Item
		{
			return _result;
		}
		
		protected var cursor:uint = 0;
			
		public function Parser(data:String):void
		{
			trace('Передано в анализатор. Память: ', Formatter.dataSize(System.totalMemory));
			splitData(data);
			data = null;
			
			result.name = MAIN_FUNCTION_NAME;
			result.children = new Array();
			
			// 2 пустых строки + 1 для установки именно на позицию
			cursor = this.data.length - 3;		
			parseBody(result);
			this.data = null;
		}
		
		protected function splitData(data:String):void
		{
			// определяем окончание строк
			var testString:String = data.slice(0, TEST_STRING_LENGTH);
			var line_ending:String = "\n";
			for (var i:uint; i < TEST_STRING_LENGTH; i++)
			{
				if (testString.charAt(i) == "\n" && testString.charAt(i - 1) == "\r")
				{
					line_ending = "\r\n";
					break;
				}
			}
			this.data = data.split(line_ending);
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
					parent.time = line_and_time[1];
					var fileName:String = data[cursor - 2].slice(3);
					if (fileName != 'php:internal')
					{
						parent.fileName = fileName;
					}
					
					cursor -= 4;
					break;
				}
				else
				{					
					var sample:String = data[cursor - 4].charAt(0);
					
					var child:Item = new Item();
					child.name = data[cursor - 2].slice(4);
					child.line = line_and_time[0];
					child.inclusiveTime = line_and_time[1] / TIME_UNIT_IN_MS;
					children.unshift(child);
		
					// следующий ребенок (cfn)
					if (sample == 'c')
					{
						cursor -= 3;
					}
					// данные о родителе после всех детей
					else
					{
						line_and_time = data[cursor - 3].split(' ');
						parent.time = line_and_time[1];
						if (sample == 'f')
						{
							parent.fileName = data[cursor - 5].slice(3);
							cursor -= 7;
		
						}
						// для функции main не указывается файл, есть строка summary, отделенная пустыми строками
						else if (sample == '')
						{
							parent.fileName = data[cursor - 8].slice(3);
							parent.inclusiveTime = data[cursor - 5].slice(9) / TIME_UNIT_IN_MS;
							
							cursor -= 10;
						}
						else
						{
							throw new Error('Неизвестный формат или ошибка анализатора');
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