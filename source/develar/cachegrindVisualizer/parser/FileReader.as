package develar.cachegrindVisualizer.parser
{	
	import develar.encryption.Sha256;
	
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	
	public class FileReader
	{
		/**
		 * Сколько байт данных обрабатывать за одно чтение
		 */
		protected static const PORTION_LENGTH:uint = 104857/* 10485760*/; // 10 МБ  
		/**
		 * Длина строки для расчета контрольной суммы (одна с начала, другая с середины)
		 */
		protected static const CHECK_STRING_LENGTH:uint = 500;		
		/**
		 * Длина строки для определения символа разделителя строк (первая строка это версия - version: 0.9.6, поэтому 20 вполне хватит)
		 */
		protected static const TEST_STRING_LENGTH:uint = 20;
		/**
		 * Длина строки для определения символа разделителя строк в порции данных и корректного дополнения нулевого элемента до полной строки
		 */
		protected static const ZERO_ELEMENT_STRING_LENGTH:uint = 250;
		
		protected static const END_EMPTY_LINE_AMOUNT:uint = 2;
		
		protected var lineEnding:String;
		
		protected var file:File;
		protected var fileStream:FileStream = new FileStream();
		
		protected var data:Array;
		protected var cursor:uint;
		
		protected var _checksum:String;
		public function get checksum():String
		{
			return _checksum;
		}
		
		public function FileReader(file:File):void
		{
			this.file = file;
			fileStream.open(file, FileMode.READ);
			
			if (file.size > (CHECK_STRING_LENGTH * 2))
			{
				_checksum = fileStream.readUTFBytes(CHECK_STRING_LENGTH);
				fileStream.position = file.size / 2;
				_checksum += fileStream.readUTFBytes(CHECK_STRING_LENGTH);		
				lineEnding = checksum.slice(0, TEST_STRING_LENGTH).search('\r\n') == -1 ? '\n' : '\r\n';
			}
			else
			{
				_checksum = fileStream.readUTFBytes(file.size);
			}
			_checksum = Sha256.hmac(checksum, String(file.size));
			
			fileStream.position = file.size - (END_EMPTY_LINE_AMOUNT * (lineEnding == '\n' ? 1 : 2));
		}
		
		public function read():void
		{
			var length:Number = PORTION_LENGTH;
			// если после чтения останется меньше, чем порция, то нам проще взять все оставшееся сразу в один заход
			if (fileStream.position < (PORTION_LENGTH * 2))
			{
				length = fileStream.position;
				fileStream.position = 0;
			}		
			else
			{
				fileStream.position -= PORTION_LENGTH;
				// корректируем позицию, чтобы в нулевом элементе данных не было оборванной строки
				if (fileStream.position != 0)
				{	
					fileStream.position -= ZERO_ELEMENT_STRING_LENGTH;
					var checkString:String = fileStream.readUTFBytes(ZERO_ELEMENT_STRING_LENGTH);
					var lastIndexOfLineEnding:int = checkString.lastIndexOf(lineEnding);
					if (lastIndexOfLineEnding == -1)
					{
						throw new Error('Хм. Однако ZERO_ELEMENT_STRING_LENGTH не хватило. Или еще что-нибудь. Киньте файлом и еще чем-нибудь тяжелым в того, кто написал это.');
					}
					var offset:uint = ZERO_ELEMENT_STRING_LENGTH - lastIndexOfLineEnding;
					fileStream.position -= offset;
					length += offset;
				}
			}
				
			data = fileStream.readUTFBytes(length).split(lineEnding);
			fileStream.position -= length;
			cursor = data.length - 1;
		}
		
		public function getLine(offset:int):String
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
				data = data.concat(remainder);
				cursor += remainder.length;
			}
			else if ((cursor - offset) == 0)
			{
				var ff:int;
				ff++;
			}
		}
		
		public function shiftCursor(offset:uint = 0):void
		{
			correctCursor(offset);
			cursor -= offset;			
		}
	}
}