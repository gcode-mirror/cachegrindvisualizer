package cachegrindVisualizer.parser
{	
	import develar.encryption.Sha256;
	
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	
	public class FileReader
	{
		protected static const CHAR_SET:String = 'us-ascii';
		/**
		 * Сколько байт данных обрабатывать за одно чтение
		 */
		protected static const PORTION_LENGTH:uint = 25 * 1024 * 1024; 
		/**
		 * Длина строки для расчета контрольной суммы (одна с начала, другая с середины)
		 */
		protected static const CHECK_STRING_LENGTH:uint = 500;
		/**
		 * Длина строки для определения символа разделителя строк в порции данных и корректного дополнения нулевого элемента до полной строки
		 */
		protected static const ZERO_ELEMENT_STRING_LENGTH:uint = 200;
		
		protected static const END_EMPTY_LINE_AMOUNT:uint = 2;
		
		protected var lineEnding:String;
		
		protected var file:File;
		protected var fileStream:FileStream = new FileStream();
		
		protected var data:Array;
		protected var partialString:String = '';
		protected var cursor:uint;
		
		public function FileReader(file:File):void
		{			
			this.file = file;
			fileStream.open(file, FileMode.READ);
			
			if (file.size > (CHECK_STRING_LENGTH * 2))
			{
				_checksum = fileStream.readMultiByte(CHECK_STRING_LENGTH, CHAR_SET);
				fileStream.position = file.size / 2;
				_checksum += fileStream.readMultiByte(CHECK_STRING_LENGTH, CHAR_SET);
			}
			else
			{
				_checksum = fileStream.readMultiByte(file.size, CHAR_SET);
			}
			lineEnding = checksum.search('\r\n') == -1 ? '\n' : '\r\n';
			_checksum = Sha256.hmac(checksum, String(file.size));
			// закрываем, так как файл может быть в кеше и чтения не будет
			fileStream.close();
			fileStream = null;
		}
		
		protected var _checksum:String;
		public function get checksum():String
		{
			return _checksum;
		}
		
		protected var _complete:Boolean = false;
		public function get complete():Boolean
		{
			if (_complete && cursor < 5)
			{
				data = null;
				fileStream.close();
				return true;
			}
			else
			{
				return false;
			}
		}
		
		public function read():void
		{
			if (fileStream == null)
			{
				fileStream = new FileStream();
				fileStream.open(file, FileMode.READ);
				fileStream.position = file.size - (END_EMPTY_LINE_AMOUNT * lineEnding.length);
			}
			
			var length:Number = PORTION_LENGTH;
			var offset:uint;
			// если после чтения останется меньше, чем порция, то нам проще взять все оставшееся сразу в один заход
			if (fileStream.position < (length * 2))
			{
				length = fileStream.position;
				fileStream.position = 0;
				_complete = true;
			}		
			else
			{
				fileStream.position -= length;
			}
			
			data = (fileStream.readMultiByte(length, CHAR_SET) + partialString).split(lineEnding);
			partialString = data.shift();
			
			fileStream.position -= length;
			cursor = data.length - 1;
		}
		
		public function getLine(offset:uint):String
		{
			correctCursor(offset);
			return data[cursor - offset];
		}
		
		protected function correctCursor(offset:uint):void
		{
			if ((cursor - offset) < 0)
			{
				var remainder:Array = data.slice(0, cursor + 1);
				read();
				// concat создает копию
				for each (var item:String in remainder)
				{
					data.push(item);
				}
				cursor += remainder.length;
			}
		}
		
		public function shiftCursor(offset:uint = 0):void
		{
			correctCursor(offset);
			cursor -= offset;			
		}
	}
}