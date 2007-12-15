package cachegrindVisualizer.callGraph.builders
{
	import cachegrindVisualizer.controls.tree.TreeItem;
	
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
		private static const PREFETCH:uint = 5000;
		private static const SELECT_NODE_SQL:String = 'select name, sum(inclusiveTime) as inclusiveTime, sum(time) / :onePercentage as percentage, sum(inclusiveTime) / :onePercentage as inclusivePercentage from main.tree where path like :path || \'%\' group by name having max(inclusiveTime) / :onePercentage >= :cost';
		
		private var selectRootItemStatement:SQLStatement = new SQLStatement();
		private var selectEdgeStatement:SQLStatement = new SQLStatement();
		private var selectNodeStatement:SQLStatement = new SQLStatement();
		
		private var fileStream:FileStream = new FileStream();
			
		private var label:Label = new Label();
		private var color:Color = new Color();
		
		private var onePercentage:Number;
		
		private var configuration:Configuration;
		
		private var treeItem:TreeItem;
		private var parentEdge:Edge;
		private var previousEdge:Edge;
		
		private var edgesBuilt:Boolean = true;
		private var nodesBuilt:Boolean = true;
		
		public function Builder():void
		{
			selectEdgeStatement.itemClass = Edge;
			selectEdgeStatement.addEventListener(SQLEvent.RESULT, handleSelectEdge);
			selectEdgeStatement.text = 'select path, name, time, inclusiveTime, time / :onePercentage as percentage, inclusiveTime / :onePercentage as inclusivePercentage, exists (select 1 from main.tree where path = pt.path || \'.\' || pt.id) as isBranch from main.tree as pt where path like :path || \'%\' and inclusivePercentage >= :cost order by path, id desc';
			
			selectNodeStatement.itemClass = Node;
			selectNodeStatement.addEventListener(SQLEvent.RESULT, handleSelectNode);
			
			selectRootItemStatement.itemClass = Edge;
			selectRootItemStatement.text = 'select time, inclusiveTime from tree where path = :path and id = :id';
			selectRootItemStatement.addEventListener(SQLEvent.RESULT, handleSelectRootItem);
		}
		
		public function get complete():Boolean
		{
			return edgesBuilt && nodesBuilt;
		}
		
		public function cancel():void
		{
			selectRootItemStatement.cancel();
			selectEdgeStatement.cancel();
			selectNodeStatement.cancel();
				
			fileStream.close();
		}
		
		public function set sqlConnection(value:SQLConnection):void
		{
			selectEdgeStatement.sqlConnection = value;
			selectNodeStatement.sqlConnection = value;
			selectRootItemStatement.sqlConnection = value;
		}
		
		public function build(treeItem:TreeItem, file:File, configuration:Configuration):void
		{	
			this.treeItem = treeItem;
			this.configuration = configuration;
			label.type = configuration.labelType;
			
			edgesBuilt = false;
			nodesBuilt = false;
			
			fileStream.openAsync(file, FileMode.WRITE);							
			var header:String = 'digraph { rankdir="' + configuration.rankDirection + '";\nedge [labelfontsize=12];\n';		
			if (configuration.title != null)
			{
				header += 'label="' + configuration.title + '" fontsize=22 labelloc="' + configuration.titleLocation + '"\n';
			}
			if (!configuration.blackAndWhite)
			{
				header += 'node [style=filled];\n';
			}		
			header += '\n';
			fileStream.writeUTFBytes(header);
			
			selectRootItem();			
		}
		
		private function selectRootItem():void
		{			
			selectRootItemStatement.parameters[':path'] = treeItem.path;
			selectRootItemStatement.parameters[':id'] = treeItem.id;
			selectRootItemStatement.execute();
		}
		
		private function handleSelectRootItem(event:SQLEvent):void
		{
			previousEdge = selectRootItemStatement.getResult().data[0];
			previousEdge.path = treeItem.path;
			previousEdge.name = treeItem.name;
			previousEdge.inclusivePercentage = 100;
			onePercentage = previousEdge.inclusiveTime / 100;
			previousEdge.percentage = previousEdge.time / onePercentage;
			previousEdge.arrowLabel = previousEdge.time > 0 ? label.arrow(previousEdge, onePercentage) : '';

			selectNodeStatement.parameters[':onePercentage'] = selectEdgeStatement.parameters[':onePercentage'] = onePercentage;
			selectNodeStatement.parameters[':cost'] = selectEdgeStatement.parameters[':cost'] = configuration.minNodeCost;
			selectNodeStatement.parameters[':path'] = selectEdgeStatement.parameters[':path'] = treeItem.path == '' ? treeItem.id : (treeItem.path + '.' + treeItem.id);
						
			selectEdgeStatement.execute(PREFETCH);
			
			selectNodeStatement.text = SELECT_NODE_SQL + " union select '" + previousEdge.name + "', " + previousEdge.inclusiveTime + ", " + previousEdge.percentage + ", 100";			
			selectNodeStatement.execute(PREFETCH);
		}
		
		private function handleSelectEdge(event:SQLEvent):void
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
				if (edge.isBranch && edge.time > 0)
				{
					edge.arrowLabel = label.arrow(edge, onePercentage);
					edges += ', headlabel="' + edge.arrowLabel + '"';
				}
				
				if (!configuration.blackAndWhite)
				{
					edges += ', color="' + color.edge(edge) + '"';
				}
				
				edges += '];\n';
				
				previousEdge = edge;
			}
			
			fileStream.writeUTFBytes(edges);
			if (sqlResult.complete)
			{	
				parentEdge = previousEdge = null;
				edgesBuilt = true;
				checkComplete();
			}
			else
			{
				selectEdgeStatement.next(PREFETCH);				
			}
		}
		
		private function handleSelectNode(event:SQLEvent):void
		{
			var nodes:String = '\n';
			var sqlResult:SQLResult = selectNodeStatement.getResult();
			for each (var node:Node in sqlResult.data)
			{
				nodes += '"' + node.name + '" [label="' + label.node(node) + '"';
				if (!configuration.blackAndWhite)
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
		
		private function checkComplete():void
		{
			if (complete)
			{
				treeItem = null;
				
				fileStream.writeUTFBytes('}');
				
				fileStream.addEventListener(Event.CLOSE, handleCloseFileStream);
				fileStream.close();
			}
		}		
		
		private function handleCloseFileStream(event:Event):void
		{
			
		}
	}
}