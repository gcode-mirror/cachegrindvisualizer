package develar.cachegrindVisualizer.callGraph.builders
{	
	import develar.cachegrindVisualizer.Item;
	import develar.cachegrindVisualizer.callGraph.Node;
	
	import flash.data.SQLConnection;
	import flash.data.SQLStatement;
	import flash.events.Event;
	import flash.events.OutputProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	
	public class Builder
	{		
		public static const RANK_DIRECTION_TB:uint = 0;
		public static const RANK_DIRECTION_LR:uint = 1;
		public static const RANK_DIRECTION_BT:uint = 2;
		public static const RANK_DIRECTION_RL:uint = 3;
		
		protected static const PREFETCH:uint = 5000;
		
		protected var selectStatement:SQLStatement = new SQLStatement();
		protected var selectNodeStatement:SQLStatement = new SQLStatement();
		protected var selectNodeWithSpecifiedParentStatement:SQLStatement = new SQLStatement();
		protected var fileStream:FileStream = new FileStream();
		
		protected var rankDirections:Array = ['TB', 'LR', 'BT', 'RL'];
			
		protected var onePercentage:Number;		
		protected var color:Color = new Color();
		
		//protected var rootId:uint 
		
		public function Builder():void
		{
			selectStatement.itemClass = Item;			
			selectStatement.text = 'select id, name, fileName, line, time, inclusiveTime, exists (select 1 from tree where parent = pt.id) as isBranch from tree as pt where parent = :parent';
			
			selectNodeStatement.itemClass = Node;
			selectNodeWithSpecifiedParentStatement.itemClass = Node;
			selectNodeStatement.text = selectNodeWithSpecifiedParentStatement.text = 'select name, sum(time) as time, sum(inclusiveTime) as inclusiveTime, round(sum(time) / 0.9, 2) as percentage, round(sum(inclusiveTime) / 0.9, 2) as inclusivePercentage from tree';
			selectNodeWithSpecifiedParentStatement.text += ' where left >= :left and rigth <= :rigth';
			selectNodeStatement.text += selectNodeWithSpecifiedParentStatement.text += 'group by name having inclusivePercentage >= :cost';
		}
		
		protected var _label:Label = new Label();
		public function get label():Label
		{
			return _label;
		}
		
		protected var _minNodeCost:Number = 1;
		public function set minNodeCost(value:Number):void
		{
			_minNodeCost = value;
		}
		
		protected var _rankDirection:uint = 0;
		public function set rankDirection(value:uint):void
		{
			_rankDirection = value;
		}		
		
		protected var _blackAndWhite:Boolean = false;
		public function set blackAndWhite(value:Boolean):void
		{
			_blackAndWhite = value;
		}
		
		public function set sqlConnection(value:SQLConnection):void
		{
			selectStatement.sqlConnection = value;
		}
		
		public function build(id:uint, file:File):void
		{				
			fileStream.openAsync(file, FileMode.WRITE);
			// вводить переменную экземпляра для передачи id лень
			var callerHandlerWriteHeader:Function = function ():void
			{
				fileStream.removeEventListener(OutputProgressEvent.OUTPUT_PROGRESS, callerHandlerWriteHeader); 
				create(id);
			}; 
			fileStream.addEventListener(OutputProgressEvent.OUTPUT_PROGRESS, callerHandlerWriteHeader);
							
			var header:String = 'digraph { rankdir="' + rankDirections[_rankDirection] + '";\nedge [labelfontsize=12];\n';		
			if (!_blackAndWhite)
			{
				header += 'node [style=filled];\n';
			}			
			header += '\n';
			fileStream.writeUTFBytes(header);
		}
		
		protected function create(id:uint):void
		{
			var selectStatement:SQLStatement = new SQLStatement();
			selectStatement.itemClass = Item;
			selectStatement.sqlConnection = this.selectStatement.sqlConnection;
			selectStatement.text = 'select id, name, fileName, line, time, inclusiveTime from tree where id = :id';
			selectStatement.parameters[':id'] = id;
			selectStatement.execute();
			var item:Item = selectStatement.getResult().data[0];
			onePercentage = item.inclusiveTime / 100;
			item.percentage = item.time / onePercentage;
			item.inclusivePercentage = 100;
				
			buildEdge(item, item.time > 0 ? label.arrow(item, onePercentage) : '');
			buildNodes();			
			fileStream.writeUTFBytes('}');
			
			fileStream.addEventListener(Event.CLOSE, handleCloseFileStream);
			fileStream.close();
		}
		
		protected function buildEdge(parent:Item, parentArrowLabel:String):void
		{
			selectStatement.parameters[':parent'] = parent.id;
			selectStatement.execute();
			for each (var item:Item in selectStatement.getResult().data)
			{
				item.inclusivePercentage = item.inclusiveTime / onePercentage;
				item.percentage = item.time / onePercentage;
				if (item.inclusivePercentage >= _minNodeCost)
				{					
					var edge:String = '"' + parent.name + '" -> "' + item.name + '" [label="' + label.edge(item) + '"';
					
					if (parentArrowLabel != '')
					{						
						edge += ', taillabel="' + parentArrowLabel + '"';
					}
										
					var itemArrowLabel:String = '';
					// если элемент не имеет детей, то смысла в метке острия стрелки нет - она всегда будет равна метке ребра
					if (item.isBranch && item.time > 0)
					{
						itemArrowLabel = label.arrow(item, onePercentage);
						edge += ', headlabel="' + itemArrowLabel + '"';
					}
					
					if (!_blackAndWhite)
					{
						edge += ', color="' + color.edge(item) + '"';
					}
					
					edge += '];\n';
					fileStream.writeUTFBytes(edge);
					
					if (item.isBranch)
					{
						buildEdge(item, itemArrowLabel);
					}
					
					//setNode(item);
				}
			}
		}
		
		/*protected function setNode(item:Item):void
		{
			if (!(item.name in nodes))
			{
				nodes[item.name] = new Node();
			}
			
			var node:Node = nodes[item.name];
			node.percentage += item.percentage;
			if (label.type > 0)
			{
				node.inclusiveTime += item.inclusiveTime;
			}
			if (label.type != Label.TYPE_TIME)
			{
				node.inclusivePercentage += item.inclusivePercentage;
			}
		}*/
		
		protected function buildNodes():void
		{
			/*selectNodeStatement.parameters[':cost'] = _minNodeCost;
			selectNodeStatement.execute(PREFETCH);
			
			
			var node:String = '';
			for (var name:String in nodes)
			{				
				node += '"' + name + '" [label="' + label.node(name, nodes[name]) + '"';
				if (!_blackAndWhite)
				{
					node += ', color="' + color.node(nodes[name]) + '"';
				}
				node += '];\n';								
			}
			nodes = null;	
			fileStream.writeUTFBytes(node);	*/		
		}		
		
		protected function handleCloseFileStream(event:Event):void
		{
			
		}
	}
}