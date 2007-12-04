package develar.cachegrindVisualizer.callGraph.builders
{
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
		protected static const SELECT_NODE_SQL:String = 'select name, sum(inclusiveTime) as inclusiveTime, sum(time) / :onePercentage as percentage, sum(inclusiveTime) / :onePercentage as inclusivePercentage from tree where path like :path || \'%\' group by name having max(inclusiveTime) / :onePercentage >= :cost';
		
		protected var selectEdgeStatement:SQLStatement = new SQLStatement();
		protected var selectNodeStatement:SQLStatement = new SQLStatement();
		protected var fileStream:FileStream = new FileStream();
		
		protected var rankDirections:Array = ['TB', 'LR', 'BT', 'RL'];
			
		protected var onePercentage:Number;		
		protected var color:Color = new Color();
		
		protected var treeItem:TreeItem;
		protected var parentEdge:Edge;
		protected var previousEdge:Edge;
		
		protected var edgesBuilt:Boolean;
		protected var nodesBuilt:Boolean;
		
		public function Builder():void
		{
			selectEdgeStatement.itemClass = Edge;
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
			selectStatement.itemClass = Edge;			
			selectStatement.sqlConnection = selectEdgeStatement.sqlConnection;
			selectStatement.addEventListener(SQLEvent.RESULT, handleSelectRootItem);
			selectStatement.text = 'select time, inclusiveTime from tree where path = :path and id = :id';
			selectStatement.parameters[':path'] = treeItem.path;
			selectStatement.parameters[':id'] = treeItem.id;
			selectStatement.execute();
		}
		
		protected function handleSelectRootItem(event:SQLEvent):void
		{
			previousEdge = event.target.getResult().data[0];
			previousEdge.path = treeItem.path;
			previousEdge.name = treeItem.name;
			previousEdge.inclusivePercentage = 100;
			onePercentage = previousEdge.inclusiveTime / 100;
			previousEdge.percentage = previousEdge.time / onePercentage;
			previousEdge.arrowLabel = previousEdge.time > 0 ? label.arrow(previousEdge, onePercentage) : '';

			selectNodeStatement.parameters[':onePercentage'] = selectEdgeStatement.parameters[':onePercentage'] = onePercentage;
			selectNodeStatement.parameters[':cost'] = selectEdgeStatement.parameters[':cost'] = _minNodeCost;
			selectNodeStatement.parameters[':path'] = selectEdgeStatement.parameters[':path'] = treeItem.path == '' ? treeItem.id : (treeItem.path + '.' + treeItem.id);
						
			selectEdgeStatement.execute(PREFETCH);
			
			selectNodeStatement.text = SELECT_NODE_SQL + " union select '" + previousEdge.name + "', " + previousEdge.inclusiveTime + ", " + previousEdge.percentage + ", 100";			
			selectNodeStatement.execute(PREFETCH);
		}
		
		protected function handleSelectEdge(event:SQLEvent):void
		{
			var edges:String = '';
			var sqlResult:SQLResult = selectEdgeStatement.getResult();
			for each (var edge:Edge in sqlResult.data)
			{
				if (edge.path.length != previousEdge.path.length) // сравнение длины, оно как число, быстрее чем строки
				{
					parentEdge = previousEdge;
				}
				
				edges += '"' + parentEdge.name + '" -> "' + edge.name + '" [label="' + label.edge(edge) + '"';
				if (parentEdge.arrowLabel != '')
				{						
					edges += ', taillabel="' + parentEdge.arrowLabel + '"';
				}
				
				// если элемент не имеет детей, то смысла в метке острия стрелки нет - она всегда будет равна метке ребра
				if (/*item.isBranch && */edge.time > 0)
				{
					edge.arrowLabel = label.arrow(edge, onePercentage);
					edges += ', headlabel="' + edge.arrowLabel + '"';
				}
				
				if (!_blackAndWhite)
				{
					edges += ', color="' + color.edge(edge) + '"';
				}
				
				edges += '];\n';
				
				previousEdge = edge;
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
				parentEdge = null;
				parentEdge = null;
				treeItem = null;
				
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