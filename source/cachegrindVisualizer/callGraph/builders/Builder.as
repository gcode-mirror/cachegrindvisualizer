package cachegrindVisualizer.callGraph.builders
{
	import cachegrindVisualizer.callGraph.builders.statementBuilder.AggregatedEdgeBuilder;
	import cachegrindVisualizer.callGraph.builders.statementBuilder.EdgeBuilder;
	import cachegrindVisualizer.callGraph.builders.statementBuilder.NodeBuilder;
	import cachegrindVisualizer.controls.tree.TreeItem;
	
	import flash.data.SQLConnection;
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
		public static const PREFETCH:uint = 5000;
		
		private var selectRootItemStatement:SQLStatement = new SQLStatement();
		
		private var progress:Number;
		
		public function Builder(sqlConnection:SQLConnection, names:Object):void
		{
			_sqlConnection = sqlConnection;
			selectRootItemStatement.sqlConnection = sqlConnection;			
			
			_label = new Label(names);
			
			selectRootItemStatement.itemClass = RootNode;
			selectRootItemStatement.text = 'select namesPath, time, inclusiveTime from tree where left = :left and right = :right';
			selectRootItemStatement.addEventListener(SQLEvent.RESULT, handleSelectRootItem);
			
			fileStream.addEventListener(Event.CLOSE, handleCloseFileStream);
		}
		
		private var _fileStream:FileStream = new FileStream();
		public function get fileStream():FileStream
		{
			return _fileStream;
		}
		
		private var _label:Label;
		public function get label():Label
		{
			return _label;
		}
		
		private var _color:Color = new Color();
		public function get color():Color
		{
			return _color;
		}
		
		private var _configuration:Configuration;
		public function get configuration():Configuration
		{
			return _configuration;
		}
		
		private var _onePercentage:Number;
		public function get onePercentage():Number
		{
			return _onePercentage;
		}
		
		private var _treeItem:TreeItem;
		public function get treeItem():TreeItem
		{
			return _treeItem;
		}
		
		private var _rootNode:RootNode
		public function get rootNode():RootNode
		{
			return _rootNode;
		}
		
		private var _sqlConnection:SQLConnection;
		public function get sqlConnection():SQLConnection
		{
			return _sqlConnection;
		}
		
		public function cancel():void
		{
			if (progress > 0)
			{
				/*var sqlErrorHandler:Function = function (event:SQLErrorEvent):void { event.target.removeEventListener(SQLErrorEvent.ERROR, sqlErrorHandler); };
				selectRootItemStatement.addEventListener(SQLErrorEvent.ERROR, sqlErrorHandler, false, 0, false);
				selectEdgeStatement.addEventListener(SQLErrorEvent.ERROR, sqlErrorHandler, false, 0, false);
				selectNodeStatement.addEventListener(SQLErrorEvent.ERROR, sqlErrorHandler, false, 0, false);
				
				selectRootItemStatement.cancel();				
				selectEdgeStatement.cancel();				
				selectNodeStatement.cancel();
				*/
				fileStream.close();
			
				progress = 0;
				dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS, false, false, progress, 100));
			}			
		}
		
		public function build(treeItem:TreeItem, file:File, configuration:Configuration):void
		{
			progress = 1;
			
			/*if (selectRootItemStatement.executing || selectEdgeStatement.executing || selectNodeStatement.executing)
			{
				selectRootItemStatement.cancel();
				selectEdgeStatement.cancel();
				selectNodeStatement.cancel();
			}*/
			
			_treeItem = treeItem;
			_configuration = configuration;
			label.type = configuration.labelType;
			
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
			
			_rootNode = selectRootItemStatement.getResult().data[0];
			rootNode.name = treeItem.name;			
			_onePercentage = rootNode.inclusiveTime / 100;			
			rootNode.percentage = rootNode.time / onePercentage;
			
			if (configuration.grouping == Grouper.FUNCTIONS_AND_CALLS || configuration.grouping == Grouper.FUNCTIONS)
			{
				rootNode.id = rootNode.name;
			}
			else if (configuration.grouping == Grouper.CALLS)
			{
				rootNode.id = rootNode.namesPath;
			}
			else
			{
				rootNode.id = treeItem.left;
			}
			
			if (configuration.grouping == Grouper.FUNCTIONS_AND_CALLS || configuration.grouping == Grouper.CALLS)
			{
				new AggregatedEdgeBuilder(this);
			}
			else
			{
				new EdgeBuilder(this);
			}
			
			new NodeBuilder(this);
			
			_treeItem = null;
		}
		
		public function checkComplete():void
		{
			progress += 45;
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS, false, false, progress, 100));
			if (progress == 100)
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