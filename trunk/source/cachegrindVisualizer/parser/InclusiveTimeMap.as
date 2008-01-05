package cachegrindVisualizer.parser
{
	import flash.data.SQLConnection;
	
	public class InclusiveTimeMap extends NameMap
	{
		private static const TABLE:String = 'inclusiveTime';
		
		public function InclusiveTimeMap(sqlConnection:SQLConnection)
		{
			super(sqlConnection, TABLE);
		}
		
		public function increment(name:uint, time:Number, left:int, right:int, childless:Boolean):void
		{
			//trace(name);			
			if (childless)
			{
				incrementChildless(name, time);
			}
			else
			{
				var item:InclusiveTimeMapItem;
				var items:Object = map[name];
				if (items == null)
				{				
					item = new InclusiveTimeMapItem();
					item.time = time;
					item.left = left;
					item.right = right;
					
					items = new Object();
					items[left]	= item;
					map[name] = items;
				}
				else			
				{
					var newItems:Object = new Object();
					for each (item in items)
					{
						var isParent:Boolean = item.left > left && item.right < right;
						var isChild:Boolean = left > item.left && right < item.right;
						if (isParent || !isChild)
						{	
							if (!isParent)
							{
								newItems[item.left] = item;
							}	
												
							var newItem:InclusiveTimeMapItem = new InclusiveTimeMapItem();
							newItem.time = time;
							newItem.left = left;
							newItem.right = right;						
							newItems[left] = newItem;
						}
					}
					map[name] = newItems;
				}
			}
		}
		
		protected function incrementChildless(name:uint, time:Number):void
		{
			if (name in values)
			{
				values[name] += time;
			}
			else
			{
				values[name] = time;
			}
		}
		
		override public function save():Object
		{			
			for (var name:String in map)
			{
				var result:Number = 0;
				for each (var item:InclusiveTimeMapItem in map[name])
				{
					result += item.time;
				}
				values[name] = result;
			}
			
			return super.save();
		}
	}
}