package develar.cachegrindVisualizer
{
	import mx.utils.ObjectUtil;
	
	public class Parser
	{
		/**
		 * Длина строки для определения символа разделителя строк (первая строка это версия - version: 0.9.6, поэтому 20 вполне хватит)
		 */
		protected const TEST_STRING_LENGTH:uint = 20;
		
		protected const HEADER_CMD_LINE_NUMBER:uint = 1;
		protected const BODY_BEGIN_LINE_NUMBER:uint = 6;
		
		protected const MAIN_FUNCTION_NAME:String = 'main';
		
		protected var data:Array;
		protected var result:Object = {metadata: {}, data: []};
		
		protected var cursor:uint = 0;
		protected var stack:Object = new Object();
		protected var currentItemId:String;
			
		public function Parser(data:String):void
		{
			trace('передано в анализатор');
			splitData(data);
			data = '';
					
			result.data = {name: MAIN_FUNCTION_NAME, children: []};
			
			// 2 пустых строки + 1 для установки именно на позицию
			cursor = this.data.length - 3;		
			parseBody(result.data);
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
		
		private function parseBody(parent:Object):void
		{
			var children:Array = new Array();
			while (true)
			{
				var line_and_time:Array = data[cursor].split(' ');				
				// нет детей
				if (data[cursor - 1].charAt(0) == 'f')
				{
					parent.time = line_and_time[1];
					parent.fileName = data[cursor - 2].slice(3);
					return;
				}
				else
				{
					var sample:String = data[cursor - 4].charAt(0);
					
					children.unshift({line: line_and_time[1], inclusiveTime: line_and_time[1], name: data[cursor - 2].slice(3)});
		
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
							result.metadata['summary'] = data[cursor - 5].slice(9);
							cursor -= 10;
						}
						else
						{
							throw new Error('Неизвестный формат или ошибка анализатора');
						}
		
						parent.children = children;
						for each (var child:Object in children)
						{
							parseBody(child);
						}
		
						return;
					}
				}
			}
		}
	}
}