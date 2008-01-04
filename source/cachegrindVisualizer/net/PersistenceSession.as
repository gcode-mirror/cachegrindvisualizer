package cachegrindVisualizer.net
{
	import develar.net.PersistenceSession;
	
	public class PersistenceSession extends develar.net.PersistenceSession
	{
		public static function get instance():cachegrindVisualizer.net.PersistenceSession
		{
			return cachegrindVisualizer.net.PersistenceSession(develar.net.PersistenceSession.instance);
		}
		
		[Bindable]
		public function get callGraphConfigurationName():String
		{
			return sharedObject.data.callGraphConfigurationName;
		}
		public function set callGraphConfigurationName(value:String):void
		{
			sharedObject.data.callGraphConfigurationName = value;
		}
		
		public function get profilerOutputDirectory():String
		{
			return sharedObject.data.profilerOutputDirectory;
		}
		public function set profilerOutputDirectory(value:String):void
		{
			sharedObject.data.profilerOutputDirectory = value;
		}
	}
}