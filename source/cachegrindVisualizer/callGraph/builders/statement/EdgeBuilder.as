package cachegrindVisualizer.callGraph.builders.statementBuilder
{
	import cachegrindVisualizer.callGraph.builders.AggregatedEdge;
	import cachegrindVisualizer.callGraph.builders.Builder;
	import cachegrindVisualizer.callGraph.builders.Edge;
	import cachegrindVisualizer.callGraph.builders.EdgeSize;
	import cachegrindVisualizer.callGraph.builders.Grouper;
	
	import develar.data.SqlBuilder;
	
	import flash.data.SQLResult;
	import flash.events.SQLEvent;
	
	public class EdgeBuilder extends StatementBuilder
	{
		protected var previousId:uint;
		protected var previousLevel:uint;
		protected var parentsIds:Object = new Object();
		
		public function EdgeBuilder(builder:Builder)
		{
			super(builder);
			sqlBuilder.statement.itemClass = Edge;		
		}
		
		override public function prepare():void
		{			
			sqlBuilder.add(SqlBuilder.FIELD, 'name', 'level');
			sqlBuilder.add(SqlBuilder.FIELD, 'time', 'inclusiveTime', 'time / :onePercentage as percentage', 'inclusiveTime / :onePercentage as inclusivePercentage');
			
			if (builder.configuration.grouping == Grouper.FUNCTIONS)
			{
				sqlBuilder.add(SqlBuilder.FIELD, 'name as id');
			}
			else if (builder.configuration.grouping == Grouper.NO)
			{
				sqlBuilder.add(SqlBuilder.FIELD, 'left as id');
			}
			
			sqlBuilder.add(SqlBuilder.ORDER_BY, 'left');			
			sqlBuilder.build();
			
			previousId = builder.rootNode.id;
			previousLevel = builder.treeItem.level;				
		}
		
		override protected function handleSelect(event:SQLEvent):void
		{
			var edges:String = '';
			var sqlResult:SQLResult = sqlBuilder.statement.getResult();
			for each (var edge:Edge in sqlResult.data)
			{
				if (edge.level > previousLevel)
				{
					parentsIds[edge.level] = previousId;
				}			
				
				edges += parentsIds[edge.level] + ' -> ' + edge.id + ' [' + build(edge) + ']\n';
				
				previousLevel = edge.level;
				previousId = edge.id;
			}
			
			builder.fileStream.writeUTFBytes(edges);
			next(sqlResult);
		}		
		
		private function build(edge:Edge):String
		{
			var result:String = EdgeSize.getSize(edge) + builder.label.edge(edge);
			if (!builder.configuration.blackAndWhite)
			{
				result += builder.color.edge(edge);
			}
			return result;
		}
	}
}