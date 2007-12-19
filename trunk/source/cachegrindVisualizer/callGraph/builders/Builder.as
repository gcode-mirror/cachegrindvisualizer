package cachegrindVisualizer.callGraph.builders
{
	import cachegrindVisualizer.controls.tree.TreeItem;
	
	import flash.data.SQLConnection;
	import flash.data.SQLResult;
	import flash.data.SQLStatement;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.ProgressEvent;
	import flash.events.SQLEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	
	public class Builder extends EventDispatcher
	{	
		private static const PREFETCH:uint = 5000;
		private static const SELECT_NODE_SQL:String = 'select name, sum(inclusiveTime) as inclusiveTime, sum(time) / :onePercentage as percentage, sum(inclusiveTime) / :onePercentage as inclusivePercentage from main.tree where path like :path || \'%\' group by name having max(inclusiveTime) / :onePercentage >= :cost';
		
		private var selectRootItemStatement:SQLStatement = new SQLStatement();
		private var selectEdgeStatement:SQLStatement = new SQLStatement();
		private var selectNodeStatement:SQLStatement = new SQLStatement();
		
		private var fileStream:FileStream = new FileStream();
			
		private var label:Label = new Label();
		private var color:Color = new Color();
		
		private var configuration:Configuration;
		
		private var treeItem:TreeItem;
		private var previousEdge:Edge;
		private var parents:Object;
		
		private var edgesBuilt:Boolean = true;
		private var nodesBuilt:Boolean = true;
		
		private var progress:Number;
		
		public function Builder():void
		{
			selectEdgeStatement.itemClass = Edge;
			selectEdgeStatement.addEventListener(SQLEvent.RESULT, handleSelectEdge);
			selectEdgeStatement.text = 'select id, path, name, time, inclusiveTime, time / :onePercentage as percentage, inclusiveTime / :onePercentage as inclusivePercentage from main.tree where path like :path || \'%\' and inclusivePercentage >= :cost order by path, id desc';
			
			selectNodeStatement.itemClass = Node;
			selectNodeStatement.addEventListener(SQLEvent.RESULT, handleSelectNode);
			
			selectRootItemStatement.itemClass = Edge;
			selectRootItemStatement.text = 'select time, inclusiveTime from tree where path = :path and id = :id';
			selectRootItemStatement.addEventListener(SQLEvent.RESULT, handleSelectRootItem);
			
			fileStream.addEventListener(Event.CLOSE, handleCloseFileStream);
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
			
			progress = 0;
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS, false, false, progress, 100));
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
			header += 'node [shape=box';
			if (!configuration.blackAndWhite)
			{
				header += ', style=filled';
			}		
			header += '];\n';
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
			progress = 10;
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS, false, false, progress, 100));
			
			previousEdge = selectRootItemStatement.getResult().data[0];
			previousEdge.id = treeItem.id;
			previousEdge.path = treeItem.path;
			previousEdge.name = treeItem.name;
			previousEdge.inclusivePercentage = 100;
			var onePercentage:Number = previousEdge.inclusiveTime / 100;
			previousEdge.percentage = previousEdge.time / onePercentage;

			selectNodeStatement.parameters[':onePercentage'] = selectEdgeStatement.parameters[':onePercentage'] = onePercentage;
			selectNodeStatement.parameters[':cost'] = selectEdgeStatement.parameters[':cost'] = configuration.minNodeCost;
			selectNodeStatement.parameters[':path'] = selectEdgeStatement.parameters[':path'] = treeItem.path == '' ? treeItem.id : (treeItem.path + '.' + treeItem.id);
				
			parents = new Object();
			parents[selectNodeStatement.parameters[':path']] = previousEdge.name;	
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
				edges += '"' + parents[edge.path] + '" -> "' + edge.name + '" [' + EdgeSize.getSize(edge);
				if (label.type != Label.TYPE_NO)
				{
					edges += ' label="' + label.edge(edge) + '"';
				}

				// если узел не имеет детей (то есть собственное время равно включенному), то смысла в метке острия ребра нет - она всегда будет равна метке ребра
				if (edge.time > 0 && edge.time != edge.inclusiveTime)
				{
					if (label.type != Label.TYPE_NO)
					{
						edges += ' headlabel="' + label.head(edge) + '"';
					}
					
					parents[edge.path + '.' + edge.id] = edge.name;
				}
				
				if (!configuration.blackAndWhite)
				{
					edges += ' color="' + color.edge(edge) + '"';
				}
				
				edges += '];\n';
				
				previousEdge = edge;
			}
			
			fileStream.writeUTFBytes(edges);
			if (sqlResult.complete)
			{	
				progress += 50;
				dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS, false, false, progress, 100));
				parents = previousEdge = null;
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
				nodes += '"' + node.name + '" [' + label.node(node);
				if (!configuration.blackAndWhite)
				{
					nodes += ', color="' + color.node(node) + '"';
				}
				nodes += '];\n';
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
				treeItem = null;
				
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