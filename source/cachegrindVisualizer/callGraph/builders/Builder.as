package cachegrindVisualizer.callGraph.builders
{
	import cachegrindVisualizer.controls.tree.TreeItem;
	
	import develar.data.SqlBuilder;
	
	import flash.data.SQLConnection;
	import flash.data.SQLResult;
	import flash.data.SQLStatement;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.ProgressEvent;
	import flash.events.SQLErrorEvent;
	import flash.events.SQLEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	
	public class Builder extends EventDispatcher
	{	
		private static const PREFETCH:uint = 5000;
		
		private var selectRootItemStatement:SQLStatement = new SQLStatement();
		private var selectEdgeStatement:SQLStatement = new SQLStatement();
		private var selectNodeStatement:SQLStatement = new SQLStatement();
		
		private var fileStream:FileStream = new FileStream();
			
		private static var color:Color = new Color();
		private var grouper:Grouper = new Grouper();
		private var label:Label;		
		
		private var configuration:Configuration;
		
		private var treeItem:TreeItem;
		
		private var previousEdge:Edge;
		private var parentsIds:Object;
		
		private var edgesBuilt:Boolean = true;
		private var nodesBuilt:Boolean = true;
		
		private var progress:Number;
		
		private var edgeBuilder:Function;
		
		public function Builder(sqlConnection:SQLConnection, names:Object):void
		{
			selectEdgeStatement.sqlConnection = sqlConnection;
			selectNodeStatement.sqlConnection = sqlConnection;
			selectRootItemStatement.sqlConnection = sqlConnection;			
			
			label = new Label(names);
			
			selectEdgeStatement.addEventListener(SQLEvent.RESULT, handleSelectEdge);
			
			selectNodeStatement.itemClass = Node;
			selectNodeStatement.addEventListener(SQLEvent.RESULT, handleSelectNode);
			
			selectRootItemStatement.itemClass = Edge;
			selectRootItemStatement.text = 'select namesPath as id, time, inclusiveTime from tree where left = :left and right = :right';
			selectRootItemStatement.addEventListener(SQLEvent.RESULT, handleSelectRootItem);
			
			fileStream.addEventListener(Event.CLOSE, handleCloseFileStream);
		}
		
		public function get complete():Boolean
		{
			return edgesBuilt && nodesBuilt;
		}
		
		public function cancel():void
		{
			if (progress > 0)
			{
				var sqlErrorHandler:Function = function (event:SQLErrorEvent):void { event.target.removeEventListener(SQLErrorEvent.ERROR, sqlErrorHandler); };
				selectRootItemStatement.addEventListener(SQLErrorEvent.ERROR, sqlErrorHandler, false, 0, false);
				selectEdgeStatement.addEventListener(SQLErrorEvent.ERROR, sqlErrorHandler, false, 0, false);
				selectNodeStatement.addEventListener(SQLErrorEvent.ERROR, sqlErrorHandler, false, 0, false);
				
				selectRootItemStatement.cancel();				
				selectEdgeStatement.cancel();				
				selectNodeStatement.cancel();
				
				fileStream.close();
			
				progress = 0;
				dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS, false, false, progress, 100));
			}			
		}
		
		public function build(treeItem:TreeItem, file:File, configuration:Configuration):void
		{
			progress = 1;
			
			if (selectRootItemStatement.executing || selectEdgeStatement.executing || selectNodeStatement.executing)
			{
				selectRootItemStatement.cancel();
				selectEdgeStatement.cancel();
				selectNodeStatement.cancel();
			}
			
			this.treeItem = treeItem;
			this.configuration = configuration;
			grouper.type = configuration.grouping;
			label.type = configuration.labelType;
			
			parentsIds = new Object();
			
			edgesBuilt = false;
			nodesBuilt = false;
			
			fileStream.openAsync(file, FileMode.WRITE);							
			var header:String = 'digraph { rankdir=' + configuration.rankDirection + '\nedge [labelfontsize=12]\n';		
			if (configuration.title != null)
			{
				header += 'label="' + configuration.title + '" fontsize=22 labelloc="' + configuration.titleLocation + '"\n';
			}
			header += 'node [shape=box';
			if (!configuration.blackAndWhite)
			{
				header += ' style=filled';
			}		
			header += ']\n';
			fileStream.writeUTFBytes(header);
			
			selectRootItem();			
		}
		
		private function selectRootItem():void
		{			
			selectRootItemStatement.parameters[':left'] = treeItem.left;
			selectRootItemStatement.parameters[':right'] = treeItem.right;
			selectRootItemStatement.execute();
		}
		
		private function handleSelectRootItem(event:SQLEvent):void
		{
			progress = 10;
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS, false, false, progress, 100));
			
			previousEdge = selectRootItemStatement.getResult().data[0];
			var onePercentage:Number = previousEdge.inclusiveTime / 100;
			previousEdge.percentage = previousEdge.time / onePercentage;
			
			selectEdgeStatement.clearParameters();
			selectNodeStatement.clearParameters();
			
			selectNodeStatement.parameters[':onePercentage'] = selectEdgeStatement.parameters[':onePercentage'] = onePercentage;
			
			var edgeSqlBuilder:SqlBuilder = new SqlBuilder();
			var nodeSqlBuilder:SqlBuilder = new SqlBuilder();
			
			grouper.buildEdgeSql(edgeSqlBuilder, selectEdgeStatement);
			grouper.buildNodeSql(nodeSqlBuilder);

			edgeSqlBuilder.add(SqlBuilder.WHERE, 'left > :left', 'right < :right');
			nodeSqlBuilder.add(SqlBuilder.WHERE, 'left > :left', 'right < :right');				
			selectNodeStatement.parameters[':left'] = selectEdgeStatement.parameters[':left'] = treeItem.left;
			selectNodeStatement.parameters[':right'] = selectEdgeStatement.parameters[':right'] = treeItem.right;
				
			if (configuration.minNodeCost > 0)
			{				
				nodeSqlBuilder.add(SqlBuilder.HAVING, 'max(inclusiveTime) >= :cost');				
				selectNodeStatement.parameters[':cost'] = selectEdgeStatement.parameters[':cost'] = configuration.minNodeCost * onePercentage;
			}
			if (configuration.hideLibraryFunctions)
			{								
				nodeSqlBuilder.add(SqlBuilder.HAVING, 'max(fileName) != 0');
			}
			
			if (grouper.groupedByCalls)
			{
				edgeBuilder = buildAggregatedEdge;
				if (configuration.minNodeCost > 0)
				{
					edgeSqlBuilder.add(SqlBuilder.HAVING, 'max(inclusiveTime) >= :cost');
				}
				if (configuration.hideLibraryFunctions)
				{
					edgeSqlBuilder.add(SqlBuilder.HAVING, 'max(fileName) != 0');
				}
			}
			else
			{
				edgeBuilder = buildEdge;
				if (configuration.minNodeCost > 0)
				{
					edgeSqlBuilder.add(SqlBuilder.WHERE, 'inclusiveTime >= :cost');
				}
				if (configuration.hideLibraryFunctions)
				{
					edgeSqlBuilder.add(SqlBuilder.WHERE, 'fileName != 0');
				}
			}			
			
			selectEdgeStatement.text = edgeSqlBuilder.build();
			selectEdgeStatement.execute(PREFETCH);
			
			if (grouper.groupedByNodes)
			{
				previousEdge.id = String(treeItem.name);
			}
			else if (configuration.grouping == Grouper.CALLS)
			{
				previousEdge.id = '.0';
			}
			selectNodeStatement.text = nodeSqlBuilder.build() + ' union select ' + treeItem.name + ', ' + previousEdge.inclusiveTime + ', ' + previousEdge.percentage + ', 100, \'' + previousEdge.id + '\'';			
			selectNodeStatement.execute(PREFETCH);
			
			trace(selectEdgeStatement.text);
			trace(selectNodeStatement.text + '\n');
			
			treeItem = null;
		}
		
		private function handleSelectEdge(event:SQLEvent):void
		{
			var edges:String = '';
			var sqlResult:SQLResult = selectEdgeStatement.getResult();
			for each (var edge:Edge in sqlResult.data)
			{
				if (edge.level > previousEdge.level)
				{
					parentsIds[edge.level] = previousEdge.id;
				}			
				
				edges += '"' + getParentEdgeId(edge) + '" -> "' + edge.id + '" [' + edgeBuilder(edge) + ']\n';
				
				previousEdge = edge;
			}
			
			fileStream.writeUTFBytes(edges);
			if (sqlResult.complete)
			{
				parentsIds = previousEdge = null;
				
				progress += 50;
				dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS, false, false, progress, 100));
				edgesBuilt = true;
				checkComplete();
			}
			else
			{
				selectEdgeStatement.next(PREFETCH);				
			}
		}
		
		private function getParentEdgeId(edge:Edge):String
		{
			if (edge.level in parentsIds)
			{					
				return parentsIds[edge.level];
			}
			else
			{
				var aggregatedEdge:AggregatedEdge = AggregatedEdge(edge);
				if (configuration.grouping == Grouper.NODES_AND_CALLS)
				{
					return aggregatedEdge.namesPath.substr(aggregatedEdge.namesPath.lastIndexOf('.') + 1);
				}
				else if (configuration.grouping == Grouper.CALLS)
				{
					return aggregatedEdge.namesPath;
				}
				
				throw new Error('');
			}
		}
		
		private function buildEdge(edge:Edge):String
		{
			var result:String = EdgeSize.getSize(edge) + label.edge(edge);
			if (!configuration.blackAndWhite)
			{
				result += color.edge(edge);
			}
			return result;
		}
		
		private function buildAggregatedEdge(aggregatedEdge:AggregatedEdge):String
		{
			var result:String = /*EdgeSize.getSize(aggregatedEdge) + */label.aggregatedEdge(aggregatedEdge);
			return result;
		}
		
		private function handleSelectNode(event:SQLEvent):void
		{
			var nodes:String = '\n';
			var sqlResult:SQLResult = selectNodeStatement.getResult();
			for each (var node:Node in sqlResult.data)
			{
				nodes += '"' + node.id + '" [' + label.node(node);
				if (!configuration.blackAndWhite)
				{
					nodes += color.node(node);
				}
				nodes += ']\n';
			}		

			fileStream.writeUTFBytes(nodes);
			if (sqlResult.complete)
			{
				progress += 40;
				dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS, false, false, progress, 100));				
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
				fileStream.writeUTFBytes('}');
				fileStream.close();
			}
		}		
		
		private function handleCloseFileStream(event:Event):void
		{
			dispatchEvent(new Event(Event.COMPLETE));
		}
	}
}