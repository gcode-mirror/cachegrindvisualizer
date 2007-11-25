package develar.cachegrindVisualizer.parser
{
	import flash.filesystem.File;
	import flash.filesystem.FileStream;
	import flash.filesystem.FileMode;
	
	import develar.encryption.Sha256;
	
	public class FileReader
	{
		/**
		 * Сколько байт данных обрабатывать за одно чтение
		 */
		protected static const PORTION_LENGTH:uint = 10485760; // 10 МБ
		/**
		 * Длина строки для расчета контрольной суммы (1 с начала, другая с середины)
		 */
		protected static const CHECK_STRING_LENGTH:uint = 512;		
		/**
		 * Длина строки для определения символа разделителя строк (первая строка это версия - version: 0.9.6, поэтому 20 вполне хватит)
		 */
		protected static const TEST_STRING_LENGTH:uint = 20;
		
		protected static const END_EMPTY_LINE_AMOUNT:uint = 2;
		
		protected var lineEnding:String;
		
		protected var file:File;
		protected var fileStream:FileStream = new FileStream();
		
		protected var _data:Array;
		public function get data():Array
		{
			return _data;
		}
		
		protected var _checksum:String;
		public function get checksum():String
		{
			return _checksum;
		}
		
		public function FileReader(file:File):void
		{
			this.file = file;
			fileStream.open(file, FileMode.READ);
			
			_checksum = fileStream.readUTFBytes(CHECK_STRING_LENGTH);
			fileStream.position = file.size / 2;
			_checksum += fileStream.readUTFBytes(CHECK_STRING_LENGTH);		
			lineEnding = checksum.slice(0, TEST_STRING_LENGTH).search('\r\n') == -1 ? '\n' : '\r\n';			
			_checksum = Sha256.hmac(checksum, String(file.size));
			
			fileStream.position = file.size - (END_EMPTY_LINE_AMOUNT * (lineEnding == '\n' ? 1 : 2));
		}
		
		public function read():void
		{
			var length:Number = PORTION_LENGTH;
			if (fileStream.position < PORTION_LENGTH)
			{
				length = fileStream.position;
				fileStream.position = 0;
			}		
			else
			{
				fileStream.position -= PORTION_LENGTH;
			}
				
			_data = fileStream.readUTFBytes(length).split(lineEnding);	
		}
	}
}