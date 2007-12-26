package cachegrindVisualizer.callGraph.builders.statementBuilder
{
	import cachegrindVisualizer.callGraph.builders.AggregatedEdge;
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
			sqlBuilder.add(SqlBuilder.FIELD, 'namesParentPath', 'parentName', 'count(*) as number', 'sum(time) as summaryTime', 'avg(time) as averageTime', 'sum(inclusiveTime) as summaryInclusiveTime', 'avg(inclusiveTime) as averageInclusiveTime', 'sum(time) / :onePercentage as summaryPercentage');
				
			if (builder.configuration.grouping == Grouper.FUNCTIONS_AND_CALLS)
			{
				sqlBuilder.add(SqlBuilder.FIELD, 'name as id');
				sqlBuilder.add(SqlBuilder.GROUP_BY, 'parentName, name');
			}
			else if (builder.configuration.grouping == Grouper.CALLS)
			{
				sqlBuilder.add(SqlBuilder.FIELD, "namesParentPath || '.' || parentName || '.' || name as id");
				sqlBuilder.add(SqlBuilder.GROUP_BY, 'namesParentPath', 'parentName', 'name');
			}
			
			sqlBuilder.add(SqlBuilder.ORDER_BY, 'left');			
			sqlBuilder.build();			
		}
		
		override protected function handleSelect(event:SQLEvent):void
		{
			var edges:String = '';
			var sqlResult:SQLResult = sqlBuilder.statement.getResult();
			for each (var edge:AggregatedEdge in sqlResult.data)
			{
				edges += '"' + getParentId(edge) + '" -> "' + edge.id + '" [' + build(edge) + ']\n';
			}
			
			builder.fileStream.writeUTFBytes(edges);
			next(sqlResult);
		}
		
		private function getParentId(edge:AggregatedEdge):String
		{
			if (builder.configuration.grouping == Grouper.FUNCTIONS_AND_CALLS)
			{
				return edge.parentName;
			}
			else if (builder.configuration.grouping == Grouper.CALLS)
			{
				return edge.namesParentPath + '.' + edge.parentName;
			}
			
			throw new Error();
		}
		
		private function build(aggregatedEdge:AggregatedEdge):String
		{
			var result:String = /*EdgeSize.getSize(aggregatedEdge) + */builder.label.aggregatedEdge(aggregatedEdge);
			return result;
		}		
	}
}