package cachegrindVisualizer.callGraph.builders.statementBuilder
{
	import cachegrindVisualizer.callGraph.builders.Grouper;
	import cachegrindVisualizer.callGraph.builders.Node;
	import cachegrindVisualizer.callGraph.builders.Builder;
	
	import develar.data.SqlBuilder;
	
	import flash.data.SQLResult;
	import flash.events.SQLEvent;
		
	public class NodeBuilder extends StatementBuilder
	{
		public function NodeBuilder(builder:Builder):void
		{
			super(builder);
			sqlBuilder.statement.itemClass = Node;
		}
		
		public function get groupedByNodes():Boolean
		{
			return builder.configuration.grouping == Grouper.NODES_AND_CALLS || builder.configuration.grouping == Grouper.NODES;
		}
		
		override protected function get grouped():Boolean
		{
			return builder.configuration.grouping != Grouper.NO;
		}
		
		override public function build():void
		{
			sqlBuilder.add(SqlBuilder.FIELD, 'name');
			if (grouped)
			{
				sqlBuilder.add(SqlBuilder.FIELD, 'sum(inclusiveTime) as inclusiveTime', 'sum(time) / :onePercentage as percentage', 'sum(inclusiveTime) / :onePercentage as inclusivePercentage');
			}
			else
			{
				sqlBuilder.add(SqlBuilder.FIELD, 'inclusiveTime as inclusiveTime', 'time / :onePercentage as percentage', 'inclusiveTime / :onePercentage as inclusivePercentage');
			}			
			
			if (groupedByNodes)
			{
				sqlBuilder.add(SqlBuilder.FIELD, 'name as id');
				sqlBuilder.add(SqlBuilder.GROUP_BY, 'name');
			}
			else if (builder.configuration.grouping == Grouper.CALLS)
			{
				sqlBuilder.add(SqlBuilder.FIELD, "namesParentPath || '.' || parentName || '.' || name as id");
				sqlBuilder.add(SqlBuilder.GROUP_BY, 'namesParentPath, parentName, name');
			}
			else
			{
				sqlBuilder.add(SqlBuilder.FIELD, 'left as id');
			}
			
			sqlBuilder.add(SqlBuilder.JOIN, 'tree');
			sqlBuilder.build();
			sqlBuilder.statement.text += 'union select ' + builder.rootNode.name + ', ' + builder.rootNode.inclusiveTime + ', ' + builder.rootNode.percentage + ', ' + builder.rootNode.inclusivePercentage + ", '" + builder.rootNode.id + "'";
		}
		
		override protected function handleSelect(event:SQLEvent):void
		{
			var nodes:String = '\n';
			var sqlResult:SQLResult = sqlBuilder.statement.getResult();
			for each (var node:Node in sqlResult.data)
			{
				nodes += '"' + node.id + '" [' + builder.label.node(node);
				if (!builder.configuration.blackAndWhite)
				{
					nodes += builder.color.node(node);
				}
				nodes += ']\n';
			}		

			builder.fileStream.writeUTFBytes(nodes);
			if (sqlResult.complete)
			{
				builder.checkComplete();
			}
			else
			{				
				sqlBuilder.statement.next(Builder.PREFETCH);
			}
		}
	}
}