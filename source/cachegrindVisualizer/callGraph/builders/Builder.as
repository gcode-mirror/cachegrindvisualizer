package cachegrindVisualizer.callGraph.builders
{
	import cachegrindVisualizer.controls.tree.TreeItem;
	
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
			
		private var label:Label;
		private var color:Color = new Color();
		
		private var configuration:Configuration;
		
		private var treeItem:TreeItem;
		
		private var previousEdge:Edge;
		private var parentsNames:Object;
		
		private var edgesBuilt:Boolean = true;
		private var nodesBuilt:Boolean = true;
		
		private var progress:Number;
		
		public function Builder(sqlConnection:SQLConnection, names:Object):void
		{
			selectEdgeStatement.sqlConnection = sqlConnection;
			selectNodeStatement.sqlConnection = sqlConnection;
			selectRootItemStatement.sqlConnection = sqlConnection;			
			
			label = new Label(names);			
			
			selectEdgeStatement.itemClass = Edge;
			selectEdgeStatement.addEventListener(SQLEvent.RESULT, handleSelectEdge);
			
			selectNodeStatement.itemClass = Node;
			selectNodeStatement.addEventListener(SQLEvent.RESULT, handleSelectNode);
			
			selectRootItemStatement.itemClass = Edge;
			selectRootItemStatement.text = 'select time, inclusiveTime from tree where left = :left and right = :right';
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
			label.type = configuration.labelType;
			
			parentsNames = new Object();
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
			previousEdge.name = treeItem.name;
			var onePercentage:Number = previousEdge.inclusiveTime / 100;
			previousEdge.percentage = previousEdge.time / onePercentage;			
			
			// необходимо, так в случае нулевого minNodeCost параметр cost нам не нужен, но он будет оставаться и без очистки будет ошибка несовпадения установленных и существующих параметров
			selectEdgeStatement.clearParameters();
			selectNodeStatement.clearParameters();

			selectNodeStatement.parameters[':onePercentage'] = selectEdgeStatement.parameters[':onePercentage'] = onePercentage;			
			selectNodeStatement.parameters[':left'] = selectEdgeStatement.parameters[':left'] = treeItem.left;
			selectNodeStatement.parameters[':right'] = selectEdgeStatement.parameters[':right'] = treeItem.right;
			
			treeItem = null;
			
			selectEdgeStatement.text = 'select level, name, time, inclusiveTime, time / :onePercentage as percentage, inclusiveTime / :onePercentage as inclusivePercentage from tree where left > :left and right < :right';
			selectNodeStatement.text = 'select name, sum(inclusiveTime) as inclusiveTime, sum(time) / :onePercentage as percentage, sum(inclusiveTime) / :onePercentage as inclusivePercentage from tree where left > :left and right < :right group by name';
			if (configuration.minNodeCost > 0)
			{
				selectNodeStatement.parameters[':cost'] = selectEdgeStatement.parameters[':cost'] = configuration.minNodeCost * onePercentage;				
				selectEdgeStatement.text += ' and inclusiveTime >= :cost';
				selectNodeStatement.text += ' having max(inclusiveTime) >= :cost';
			}
			if (configuration.hideLibraryFunctions)
			{
				if (configuration.minNodeCost == 0)
				{
					selectNodeStatement.text += ' having';
				}
				else
				{
					selectNodeStatement.text += ' and';
				}
				selectEdgeStatement.text += ' and fileName  != 0'
				selectNodeStatement.text += ' max(fileName) != 0';
			}
			
			selectEdgeStatement.execute(PREFETCH);
			
			selectNodeStatement.text += " union select '" + previousEdge.name + "', " + previousEdge.inclusiveTime + ", " + previousEdge.percentage + ", 100";			
			selectNodeStatement.execute(PREFETCH);
		}
		
		private function handleSelectEdge(event:SQLEvent):void
		{
			var edges:String = '';
			var sqlResult:SQLResult = selectEdgeStatement.getResult();
			for each (var edge:Edge in sqlResult.data)
			{
				if (edge.level > previousEdge.level)
				{
					parentsNames[edge.level] = previousEdge.name;
				}				
						
				edges += parentsNames[edge.level] + ' -> ' + edge.name + ' [' + EdgeSize.getSize(edge);
				if (label.type != Label.TYPE_NO)
				{
					edges += ' label="' + label.edge(edge) + '"';
					// если узел не имеет детей (то есть собственное время равно включенному), то смысла в метке острия ребра нет - она всегда будет равна метке ребра
					if (edge.time > 0 && edge.time != edge.inclusiveTime)
					{
						edges += ' headlabel="' + label.head(edge) + '"';
					}
				}				
				if (!configuration.blackAndWhite)
				{
					edges += ' color="' + color.edge(edge) + '"';
				}								
				edges += ']\n';
				
				previousEdge = edge;
			}
			
			fileStream.writeUTFBytes(edges);
			if (sqlResult.complete)
			{	
				parentsNames = previousEdge = null;
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
		
		private function handleSelectNode(event:SQLEvent):void
		{
			var nodes:String = '\n';
			var sqlResult:SQLResult = selectNodeStatement.getResult();
			for each (var node:Node in sqlResult.data)
			{
				nodes += node.name + ' [' + label.node(node);
				if (!configuration.blackAndWhite)
				{
					nodes += ' color="' + color.node(node) + '"';
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