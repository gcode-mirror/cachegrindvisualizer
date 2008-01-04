package cachegrindVisualizer.callGraph.builders
{
	import cachegrindVisualizer.callGraph.builders.edge.AggregatedEdgeBuilder;
	import cachegrindVisualizer.callGraph.builders.edge.EdgeBuilder;
	import cachegrindVisualizer.controls.tree.TreeItem;
	
	import flash.data.SQLConnection;
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
		public static const PREFETCH:uint = 5000;
		public static const FONT:String = 'Trebuchet MS';
		
		private var selectRootItemStatement:SQLStatement = new SQLStatement();
		
		private var progress:Number;
		private var statementBuilders:Array;
		
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
				if (selectRootItemStatement.executing)
				{
					var sqlErrorHandler:Function = function (event:SQLErrorEvent):void { event.target.removeEventListener(SQLErrorEvent.ERROR, sqlErrorHandler); };
					selectRootItemStatement.addEventListener(SQLErrorEvent.ERROR, sqlErrorHandler, false, 0, false);				
					selectRootItemStatement.cancel();
				}
				
				for each (var statementBuilder:StatementBuilder in statementBuilders)
				{
					statementBuilder.cancel();
				}
				statementBuilders = null;
				
				fileStream.close();
			
				progress = 0;
				dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS, false, false, progress, 100));
			}			
		}
		
		public function build(treeItem:TreeItem, file:File, configuration:Configuration):void
		{
			cancel();
			progress = 1;
			
			_treeItem = treeItem;
			_configuration = configuration;
			label.type = configuration.labelType;
			
			fileStream.openAsync(file, FileMode.WRITE);							
			fileStream.writeUTFBytes('digraph {rankdir=' + configuration.rankDirection + ' ordering=out fontname="' + FONT + '"');
			if (configuration.title != null)
			{
				fileStream.writeUTFBytes(' label="' + configuration.title + '" fontsize=20 labelloc=' + configuration.titleLocation);
			}
			fileStream.writeUTFBytes('\n');
			
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
				rootNode.id = Math.abs(treeItem.left);
			}
			
			statementBuilders = new Array();
			if (configuration.grouping == Grouper.FUNCTIONS_AND_CALLS || configuration.grouping == Grouper.CALLS)
			{
				statementBuilders.push(new AggregatedEdgeBuilder(this));
			}
			else
			{
				statementBuilders.push(new EdgeBuilder(this));
			}
			
			statementBuilders.push(new NodeBuilder(this));
			
			_treeItem = null;
		}
		
		public function checkComplete():void
		{
			progress += 45;
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS, false, false, progress, 100));
			if (progress == 100)
			{
				statementBuilders = null;
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