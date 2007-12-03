package develar.cachegrindVisualizer.controls.tree
{
	import flash.data.SQLConnection;
	import flash.data.SQLStatement;
	
	import mx.collections.ICollectionView;
	import mx.collections.ArrayCollection;
	import mx.controls.treeClasses.DefaultDataDescriptor;
	
	public class TreeDataDescriptor extends DefaultDataDescriptor
	{
		protected var selectStatement:SQLStatement = new SQLStatement();
		
		public function TreeDataDescriptor(sqlConnection:SQLConnection):void
		{
			selectStatement.itemClass = TreeItem;
			selectStatement.sqlConnection = sqlConnection;
			selectStatement.text = 'select id, name, fileName, exists (select 1 from tree where parent = pt.id) as isBranch from tree as pt where parent = :parent';
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
				selectStatement.parameters[':parent'] = node.id;
				selectStatement.execute();
				node.children = new ArrayCollection(selectStatement.getResult().data);
			}
			
			return node.children;
		}
	}
}