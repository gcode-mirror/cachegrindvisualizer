package cachegrindVisualizer.callGraph.builders
{
	public class Configuration
	{
		public static const TITLE_LOCATION_TOP:String = 't';
		public static const TITLE_LOCATION_BOTTOM:String = 'b';
		
		public static const RANK_DIRECTION_TB:String = 'TB';
		public static const RANK_DIRECTION_LR:String = 'LR';
		public static const RANK_DIRECTION_BT:String = 'BT';
		public static const RANK_DIRECTION_RL:String = 'RL';
		
		public var minNodeCost:Number = 1;
		
		public var title:String;
		public var titleLocation:String = TITLE_LOCATION_BOTTOM;
		
		public var blackAndWhite:Boolean = false;
		
		public var rankDirection:String = RANK_DIRECTION_TB;
		public var labelType:uint = Label.TYPE_PERCENTAGE_AND_TIME;
	}
}