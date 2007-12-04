package develar.cachegrindVisualizer.callGraph.builders
{	
	import develar.cachegrindVisualizer.Item;
	import develar.cachegrindVisualizer.callGraph.Node;
	import develar.cachegrindVisualizer.controls.tree.TreeItem;
	
	import flash.data.SQLConnection;
	import flash.data.SQLResult;
	import flash.data.SQLStatement;
	import flash.events.Event;
	import flash.events.SQLEvent;
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
		protected static const SELECT_NODE_SQL:String = 'select name, sum(inclusiveTime) as inclusiveTime, sum(time) / :onePercentage as percentage, sum(inclusiveTime) / :onePercentage as inclusivePercentage from tree where path like :path || \'%\' group by name having inclusivePercentage >= :cost';
		
		protected var selectEdgeStatement:SQLStatement = new SQLStatement();
		protected var selectNodeStatement:SQLStatement = new SQLStatement();
		protected var fileStream:FileStream = new FileStream();
		
		protected var rankDirections:Array = ['TB', 'LR', 'BT', 'RL'];
			
		protected var onePercentage:Number;		
		protected var color:Color = new Color();
		
		protected var treeItem:TreeItem;
		protected var parentItem:Item;
		protected var previousItem:Item;
		
		protected var edgesBuilt:Boolean;
		protected var nodesBuilt:Boolean;
		
		public function Builder():void
		{
			selectEdgeStatement.itemClass = Item;
			selectEdgeStatement.addEventListener(SQLEvent.RESULT, handleSelectEdge);
			selectEdgeStatement.text = 'select path, name, time, inclusiveTime, time / :onePercentage as percentage, inclusiveTime / :onePercentage as inclusivePercentage from tree where path like :path || \'%\' and inclusivePercentage >= :cost order by path, id desc';
			
			selectNodeStatement.itemClass = Node;
			selectNodeStatement.addEventListener(SQLEvent.RESULT, handleSelectNode);			
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
			selectEdgeStatement.sqlConnection = value;
			selectNodeStatement.sqlConnection = value;
		}
		
		public function build(treeItem:TreeItem, file:File):void
		{	
			edgesBuilt = false;
			nodesBuilt = false;
				
			this.treeItem = treeItem;
			fileStream.openAsync(file, FileMode.WRITE);
							
			var header:String = 'digraph { rankdir="' + rankDirections[_rankDirection] + '";\nedge [labelfontsize=12];\n';		
			if (!_blackAndWhite)
			{
				header += 'node [style=filled];\n';
			}			
			header += '\n';
			fileStream.writeUTFBytes(header);
			
			selectEdgeStatement.sqlConnection.begin();
			selectRootItem();			
		}
		
		protected function selectRootItem():void
		{
			var selectStatement:SQLStatement = new SQLStatement();
			selectStatement.itemClass = Item;			
			selectStatement.sqlConnection = selectEdgeStatement.sqlConnection;
			selectStatement.addEventListener(SQLEvent.RESULT, handleSelectRootItem);
			selectStatement.text = 'select time, inclusiveTime from tree where path = :path and id = :id';
			selectStatement.parameters[':path'] = treeItem.path;
			selectStatement.parameters[':id'] = treeItem.id;
			selectStatement.execute();
		}
		
		protected function handleSelectRootItem(event:SQLEvent):void
		{
			previousItem = event.target.getResult().data[0];
			previousItem.path = treeItem.path;
			previousItem.name = treeItem.name;
			previousItem.inclusivePercentage = 100;
			previousItem.percentage = previousItem.time / onePercentage;
			
			onePercentage = previousItem.inclusiveTime / 100;
			previousItem.arrowLabel = previousItem.time > 0 ? label.arrow(previousItem, onePercentage) : '';

			selectNodeStatement.parameters[':onePercentage'] = selectEdgeStatement.parameters[':onePercentage'] = onePercentage;
			selectNodeStatement.parameters[':cost'] = selectEdgeStatement.parameters[':cost'] = _minNodeCost;
			selectNodeStatement.parameters[':path'] = selectEdgeStatement.parameters[':path'] = treeItem.path == '' ? treeItem.id : (treeItem.path + '.' + treeItem.id);
						
			selectEdgeStatement.execute(PREFETCH);
			
			selectNodeStatement.text = "select '" + previousItem.name + "', " + previousItem.inclusiveTime + ", " + previousItem.percentage + ", 100 union " + SELECT_NODE_SQL;			
			selectNodeStatement.execute(PREFETCH);
		}
		
		protected function handleSelectEdge(event:SQLEvent):void
		{
			var edges:String = '';
			var sqlResult:SQLResult = selectEdgeStatement.getResult();
			for each (var item:Item in sqlResult.data)
			{
				if (item.path.length != previousItem.path.length) // сравнение длины, оно как число, быстрее чем строки
				{
					parentItem = previousItem;
				}
				
				edges += '"' + parentItem.name + '" -> "' + item.name + '" [label="' + label.edge(item) + '"';
				if (parentItem.arrowLabel != '')
				{						
					edges += ', taillabel="' + parentItem.arrowLabel + '"';
				}
				
				// если элемент не имеет детей, то смысла в метке острия стрелки нет - она всегда будет равна метке ребра
				if (/*item.isBranch && */item.time > 0)
				{
					item.arrowLabel = label.arrow(item, onePercentage);
					edges += ', headlabel="' + item.arrowLabel + '"';
				}
				
				if (!_blackAndWhite)
				{
					edges += ', color="' + color.edge(item) + '"';
				}
				
				edges += '];\n';
				
				previousItem = item;
			}
			
			fileStream.writeUTFBytes(edges);
			if (sqlResult.complete)
			{	
				edgesBuilt = true;
				checkComplete();
			}
			else
			{
				selectEdgeStatement.next(PREFETCH);				
			}
		}
		
		protected function handleSelectNode(event:SQLEvent):void
		{
			var nodes:String = '\n';
			var sqlResult:SQLResult = selectNodeStatement.getResult();
			for each (var node:Node in sqlResult.data)
			{
				nodes += '"' + node.name + '" [label="' + label.node(node) + '"';
				if (!_blackAndWhite)
				{
					nodes += ', color="' + color.node(node) + '"';
				}
				nodes += '];\n';
			}		

			fileStream.writeUTFBytes(nodes);
			if (sqlResult.complete)
			{
				nodesBuilt = true;
				checkComplete();
			}
			else
			{
				selectNodeStatement.next(PREFETCH);
			}
		}
		
		protected function checkComplete():void
		{
			if (edgesBuilt && nodesBuilt)
			{
				fileStream.writeUTFBytes('}');
				
				fileStream.addEventListener(Event.CLOSE, handleCloseFileStream);
				fileStream.close();
			}
		}		
		
		protected function handleCloseFileStream(event:Event):void
		{
			
		}
	}
}