/**
 * @author Vladimir Krivosheev
 * @version $Id: PersistenceSession.as 250 2007-11-20 18:03:18Z develar $
 */
package develar.cachegrindVisualizer.net
{
	import develar.net.PersistenceSession;
	
	public class PersistenceSession extends develar.net.PersistenceSession
	{
		public static function get instance():develar.cachegrindVisualizer.net.PersistenceSession
		{
			return develar.cachegrindVisualizer.net.PersistenceSession(develar.net.PersistenceSession.instance);
		}
		
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
		
		public function get automaticallyBuildGraph():Boolean
		{
			if ('automaticallyBuildGraph' in sharedObject.data)
			{
				return sharedObject.data.automaticallyBuildGraph;
			}
			else
			{
				return true;
			}
		}
		public function set automaticallyBuildGraph(value:Boolean):void
		{
			sharedObject.data.automaticallyBuildGraph = value;
		}
	}
}