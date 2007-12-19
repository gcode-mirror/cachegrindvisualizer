package cachegrindVisualizer.controls.tree
{
	import flash.data.SQLConnection;
	import flash.data.SQLMode;
	import flash.data.SQLStatement;
	import flash.filesystem.File;
	
	import mx.collections.ArrayCollection;
	import mx.collections.ICollectionView;
	import mx.controls.treeClasses.DefaultDataDescriptor;
	
	public class TreeDataDescriptor extends DefaultDataDescriptor
	{
		protected var selectStatement:SQLStatement = new SQLStatement();
		
		public function TreeDataDescriptor(db:File):void
		{	
			var sqlConnection:SQLConnection = new SQLConnection();
			sqlConnection.open(db, SQLMode.READ);
								
			selectStatement.itemClass = TreeItem;
			selectStatement.sqlConnection = sqlConnection;
			selectStatement.text = 'select left, right, level, name, fileName, (time != inclusiveTime) as isBranch from tree where left > :left and right < :right and level = :level order by left';
		}
		
		override public function hasChildren(node:Object, model:Object = null):Boolean
		{
			return isBranch(node);
		}
		
		override public function isBranch(node:Object, model:Object = null):Boolean
		{
			return node.isBranch;
		}
		
		override public function getChildren(node:Object, model:Object=null):ICollectionView
		{
			var item:TreeItem = TreeItem(node);
			if (node.children == null)
			{
				selectStatement.parameters[':left'] = item.left;
				selectStatement.parameters[':right'] = item.right;
				selectStatement.parameters[':level'] = item.level + 1;
				selectStatement.execute();
				node.children = new ArrayCollection(selectStatement.getResult().data);
			}
			
			return node.children;
		}
	}
}