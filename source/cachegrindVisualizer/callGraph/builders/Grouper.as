package cachegrindVisualizer.callGraph.builders
{
	import develar.data.SqlBuilder;
	
	import flash.data.SQLStatement;
	
	public class Grouper
	{
		public static const NODES_AND_CALLS:uint = 0;
		public static const NODES:uint = 1;
		public static const CALLS:uint = 2;
		public static const NO:uint = 3;
		
		private var _type:uint = NODES_AND_CALLS;
		public function set type(value:uint):void
		{
			_type = value;
		}
		
		public function get groupedByCalls():Boolean
		{
			return _type == NODES_AND_CALLS || _type == CALLS;
		}
		
		public function get groupedByNodes():Boolean
		{
			return _type == NODES_AND_CALLS || _type == NODES;
		}
		
		public function buildEdgeSql(edgeSqlBuilder:SqlBuilder, edgeSqlStatement:SQLStatement):void
		{
			edgeSqlBuilder.add(SqlBuilder.FIELD, 'name', 'level');
			if (groupedByCalls)
			{
				edgeSqlBuilder.add(SqlBuilder.FIELD, 'namesPath', 'count(*) as number', 'sum(time) as summaryTime', 'avg(time) as averageTime', 'sum(inclusiveTime) as summaryInclusiveTime', 'avg(inclusiveTime) as averageInclusiveTime', 'sum(time) / :onePercentage as summaryPercentage');
				edgeSqlStatement.itemClass = AggregatedEdge;
				
				if (_type == NODES_AND_CALLS)
				{
					edgeSqlBuilder.add(SqlBuilder.FIELD, 'name as id');
					edgeSqlBuilder.add(SqlBuilder.GROUP_BY, 'name');
				}
				else if (_type == CALLS)
				{
					edgeSqlBuilder.add(SqlBuilder.FIELD, "namesPath || '.' || name as id");
					edgeSqlBuilder.add(SqlBuilder.GROUP_BY, 'namesPath, name');
				}
			}
			else
			{		
				edgeSqlBuilder.add(SqlBuilder.FIELD, 'name as id');
				edgeSqlBuilder.add(SqlBuilder.FIELD, 'time', 'inclusiveTime', 'time / :onePercentage as percentage', 'inclusiveTime / :onePercentage as inclusivePercentage');
				edgeSqlStatement.itemClass = Edge;
			}
			
			edgeSqlBuilder.add(SqlBuilder.ORDER_BY, 'left');
			edgeSqlBuilder.add(SqlBuilder.JOIN, 'tree');
		}
		
		public function buildNodeSql(nodeSqlBuilder:SqlBuilder):void
		{						
			nodeSqlBuilder.add(SqlBuilder.FIELD, 'name', 'sum(inclusiveTime) as inclusiveTime', 'sum(time) / :onePercentage as percentage', 'sum(inclusiveTime) / :onePercentage as inclusivePercentage');
			if (groupedByNodes)
			{
				nodeSqlBuilder.add(SqlBuilder.FIELD, 'name as id');
				nodeSqlBuilder.add(SqlBuilder.GROUP_BY, 'name');
			}
			else if (_type == CALLS)
			{
				nodeSqlBuilder.add(SqlBuilder.FIELD, "namesPath || '.' || name as id");
				nodeSqlBuilder.add(SqlBuilder.GROUP_BY, 'namesPath, name');
			}
			else
			{
				nodeSqlBuilder.add(SqlBuilder.FIELD, 'name as id');
				//nodeSqlBuilder.add(SqlBuilder.GROUP_BY, 'id');		
			}
			nodeSqlBuilder.add(SqlBuilder.JOIN, 'tree');
		}
	}
}