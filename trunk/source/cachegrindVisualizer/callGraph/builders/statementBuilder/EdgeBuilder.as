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
		private var previousId:String;
		private var previousLevel:uint;
		private var parentsIds:Object = new Object();
		
		private var edgeBuilder:Function;
		
		public function EdgeBuilder(builder:Builder)
		{
			super(builder);			
		}
		
		override protected function get grouped():Boolean
		{
			return groupedByCalls;
		}
		
		public function get groupedByCalls():Boolean
		{
			return builder.configuration.grouping == Grouper.NODES_AND_CALLS || builder.configuration.grouping == Grouper.CALLS;
		}
		
		override public function build():void
		{
			sqlBuilder.add(SqlBuilder.FIELD, 'name', 'level');
			if (grouped)
			{
				sqlBuilder.add(SqlBuilder.FIELD, 'namesParentPath', 'parentName', 'count(*) as number', 'sum(time) as summaryTime', 'avg(time) as averageTime', 'sum(inclusiveTime) as summaryInclusiveTime', 'avg(inclusiveTime) as averageInclusiveTime', 'sum(time) / :onePercentage as summaryPercentage');
				sqlBuilder.statement.itemClass = AggregatedEdge;
			}
			else
			{
				sqlBuilder.add(SqlBuilder.FIELD, 'time', 'inclusiveTime', 'time / :onePercentage as percentage', 'inclusiveTime / :onePercentage as inclusivePercentage');
				sqlBuilder.statement.itemClass = Edge;
			}
			
			if (groupedByCalls)
			{
				if (builder.configuration.grouping == Grouper.NODES_AND_CALLS)
				{
					sqlBuilder.add(SqlBuilder.FIELD, 'name as id');
					sqlBuilder.add(SqlBuilder.GROUP_BY, 'parentName, name');
				}
				else if (builder.configuration.grouping == Grouper.CALLS)
				{
					sqlBuilder.add(SqlBuilder.FIELD, "namesParentPath || '.' || parentName || '.' || name as id");
					sqlBuilder.add(SqlBuilder.GROUP_BY, 'namesParentPath', 'parentName', 'name');
				}
				
				edgeBuilder = buildAggregatedEdge;
			}
			else
			{		
				edgeBuilder = buildEdge;
				if (builder.configuration.grouping == Grouper.NODES)
				{
					sqlBuilder.add(SqlBuilder.FIELD, 'name as id');
				}
				else if (builder.configuration.grouping == Grouper.NO)
				{
					sqlBuilder.add(SqlBuilder.FIELD, 'left as id');
				}
			}
			
			sqlBuilder.add(SqlBuilder.JOIN, 'tree');
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
				
				edges += '"' + getParentId(edge) + '" -> "' + edge.id + '" [' + edgeBuilder(edge) + ']\n';
				
				previousLevel = edge.level;
				previousId = edge.id;
			}
			
			builder.fileStream.writeUTFBytes(edges);
			if (sqlResult.complete)
			{
				parentsIds = null;

				builder.checkComplete();
			}
			else
			{
				sqlBuilder.statement.next(Builder.PREFETCH);				
			}
		}
		
		/**
		 * надо отрефаторить
		 */
		private function getParentId(edge:Edge):String
		{
			if (edge is AggregatedEdge)
			{
				var aggregatedEdge:AggregatedEdge = AggregatedEdge(edge);
				if (builder.configuration.grouping == Grouper.NODES_AND_CALLS)
				{
					return aggregatedEdge.parentName;
				}
				else if (builder.configuration.grouping == Grouper.CALLS)
				{
					return aggregatedEdge.namesParentPath + '.' + aggregatedEdge.parentName;
				}
			}			
			else (edge.level in parentsIds)
			{
				return parentsIds[edge.level];
			}
				
			throw new Error('');
		}
		
		/*private function getParentId(edge:Edge):String
		{
			if (edge.level in parentsIds)
			{					
				return parentsIds[edge.level];
			}
			else
			{
				var aggregatedEdge:AggregatedEdge = AggregatedEdge(edge);
				if (builder.configuration.grouping == Grouper.NODES_AND_CALLS)
				{
					//return aggregatedEdge.namesPath.substr(aggregatedEdge.namesPath.lastIndexOf('.') + 1);
				}
				else if (builder.configuration.grouping == Grouper.CALLS)
				{
					return aggregatedEdge.namesParentPath + '.' + aggregatedEdge.parentName;
				}
				
				throw new Error('');
			}
		}*/
		
		private function buildEdge(edge:Edge):String
		{
			var result:String = EdgeSize.getSize(edge) + builder.label.edge(edge);
			if (!builder.configuration.blackAndWhite)
			{
				result += builder.color.edge(edge);
			}
			return result;
		}
		
		private function buildAggregatedEdge(aggregatedEdge:AggregatedEdge):String
		{
			var result:String = /*EdgeSize.getSize(aggregatedEdge) + */builder.label.aggregatedEdge(aggregatedEdge);
			return result;
		}
	}
}