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
		protected var cursor:uint = 0;
			
		public function Parser(data:String):void
		{
			trace('Получено. Память: ', Formatter.dataSize(System.totalMemory));
			this.data = data.split(data.slice(0, TEST_STRING_LENGTH).search('\r\n') == -1 ? '\n' : '\r\n');
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