package cachegrindVisualizer.callGraph.builders
{
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
		
		override protected function get grouped():Boolean
		{
			return builder.configuration.grouping != Grouper.NO;
		}
		
		override public function writeAttributeStatement():void
		{
			builder.fileStream.writeUTFBytes('node [shape=box fontsize=12 fontname="' + Builder.FONT + '"');
			if (!builder.configuration.blackAndWhite)
			{
				builder.fileStream.writeUTFBytes(' color="' + Color.MIN_HUE + ' ' + Color.MIN_SATURATION + ' ' + Color.MAX_VALUE + '" style=filled');
			}	
			builder.fileStream.writeUTFBytes(']\n');
		}
		
		override public function prepare():void
		{
			sqlBuilder.add(SqlBuilder.FIELD, 'name');
			if (grouped)
			{
				sqlBuilder.add(SqlBuilder.FIELD, 'sum(time) / :onePercentage as percentage');
				
				if (builder.configuration.grouping == Grouper.FUNCTIONS_AND_CALLS || builder.configuration.grouping == Grouper.FUNCTIONS)
				{
					sqlBuilder.add(SqlBuilder.FIELD, '0 as inclusiveTime');
					
					sqlBuilder.add(SqlBuilder.FIELD, 'name as id');
					sqlBuilder.add(SqlBuilder.GROUP_BY, 'name');
				}
				else if (builder.configuration.grouping == Grouper.CALLS)
				{
					sqlBuilder.add(SqlBuilder.FIELD, 'sum(inclusiveTime) as inclusiveTime');
					
					sqlBuilder.add(SqlBuilder.FIELD, 'namesPath as id');
					sqlBuilder.add(SqlBuilder.GROUP_BY, 'namesPath');
				}
			}
			else
			{
				sqlBuilder.add(SqlBuilder.FIELD, 'time / :onePercentage as percentage');
				
				sqlBuilder.add(SqlBuilder.FIELD, 'inclusiveTime');
				
				sqlBuilder.add(SqlBuilder.FIELD, 'abs(left) as id');
			}			
			
			sqlBuilder.build();
			sqlBuilder.statement.text += 'union select ' + builder.rootNode.name + ', ' + builder.rootNode.percentage + ', ' + builder.rootNode.inclusiveTime + ', ' + builder.rootNode.id;
		}
		
		override protected function handleSelect(event:SQLEvent):void
		{
			var nodes:String = '\n';
			var sqlResult:SQLResult = sqlBuilder.statement.getResult();
			for each (var node:Node in sqlResult.data)
			{
				if (builder.configuration.grouping == Grouper.FUNCTIONS_AND_CALLS || builder.configuration.grouping == Grouper.FUNCTIONS)
				{
					node.inclusiveTime = builder.inclusiveTime[node.name];
				}
				nodes += node.id + ' [' + builder.label.node(node, builder.onePercentage);
				if (!builder.configuration.blackAndWhite)
				{
					nodes += builder.color.node(node);
				}
				nodes += ']\n';
			}		

			builder.fileStream.writeUTFBytes(nodes);
			next(sqlResult);			
		}
	}
}