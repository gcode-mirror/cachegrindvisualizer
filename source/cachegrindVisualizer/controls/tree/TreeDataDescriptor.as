package cachegrindVisualizer.controls.tree
{
	import flash.data.SQLConnection;
	import flash.data.SQLStatement;
	import flash.data.SQLMode;
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
			selectStatement.text = 'select id, name, fileName, path, exists (select 1 from tree where path = pt.path || \'.\' || pt.id) as isBranch from tree as pt where path = :path order by id desc';
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
			if (node.children == null)
			{
				selectStatement.parameters[':path'] = node.path == '' ? node.id : (node.path + '.' + node.id);
				selectStatement.execute();
				node.children = new ArrayCollection(selectStatement.getResult().data);
			}
			
			return node.children;
		}
	}
}