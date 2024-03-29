package cachegrindVisualizer.callGraph.builders.edge
{
	import cachegrindVisualizer.callGraph.builders.Builder;
	import cachegrindVisualizer.callGraph.builders.Grouper;
	
	import develar.data.SqlBuilder;
	
	import flash.data.SQLResult;
	import flash.events.SQLEvent;

	public class AggregatedEdgeBuilder extends EdgeBuilder
	{
		public function AggregatedEdgeBuilder(builder:Builder)
		{
			super(builder);
			sqlBuilder.statement.itemClass = AggregatedEdge;
		}
		
		override protected function get grouped():Boolean
		{
			return true;
		}
		
		override public function prepare():void
		{
			sqlBuilder.add(SqlBuilder.FIELD, 'name', 'level');
			sqlBuilder.add(SqlBuilder.FIELD, 'sum(inclusiveTime) as summaryInclusiveTime', 'parentName', 'count(*) as number', 'avg(inclusiveTime) as averageInclusiveTime', 'min(inclusiveTime) as minimumInclusiveTime', 'max(inclusiveTime) as maximumInclusiveTime');
				
			if (builder.configuration.grouping == Grouper.FUNCTIONS_AND_CALLS)
			{
				sqlBuilder.add(SqlBuilder.FIELD, 'name as id');
				sqlBuilder.add(SqlBuilder.GROUP_BY, 'parentName, name');
				
				sqlBuilder.add(SqlBuilder.FIELD, 'max(time) / :onePercentage as sizeBase');
			}
			else if (builder.configuration.grouping == Grouper.CALLS)
			{
				sqlBuilder.add(SqlBuilder.FIELD, 'namesPath as id');
				sqlBuilder.add(SqlBuilder.GROUP_BY, 'namesPath');
				
				sqlBuilder.add(SqlBuilder.FIELD, 'sum(inclusiveTime) / :onePercentage as sizeBase');
			}
			
			sqlBuilder.add(SqlBuilder.ORDER_BY, 'min(left)');			
			sqlBuilder.build();
			
			previousId = builder.rootNode.id;
			previousLevel = builder.treeItem.level;			
		}
		
		override protected function handleSelect(event:SQLEvent):void
		{
			var edges:String = '';
			var sqlResult:SQLResult = sqlBuilder.statement.getResult();
			for each (var edge:AggregatedEdge in sqlResult.data)
			{				
				if (edge.level > previousLevel)
				{
					parentsIds[edge.level] = previousId;
				}
				
				edges += getParentId(edge) + ' -> ' + edge.id + ' [' + build(edge) + ']\n';
				
				previousLevel = edge.level;
				previousId = edge.id;
			}
			
			builder.fileStream.writeUTFBytes(edges);
			next(sqlResult);
		}
		
		override protected function getParentId(edge:Edge):uint
		{
			if (builder.configuration.grouping == Grouper.FUNCTIONS_AND_CALLS)
			{
				builder.nodesNames[edge.name] = null;
				return AggregatedEdge(edge).parentName;
			}
			else if (builder.configuration.grouping == Grouper.CALLS)
			{
				return super.getParentId(edge);
			}
			
			throw new Error();
		}
		
		private function build(edge:AggregatedEdge):String
		{
			var result:String = builder.label.aggregatedEdge(edge, builder.onePercentage) + size.edge(edge);
			if (!builder.configuration.blackAndWhite)
			{
				result += builder.color.edge(edge);
			}
			return result;
		}		
	}
}