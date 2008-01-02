package cachegrindVisualizer.callGraph.builders
{
	import develar.data.SqlBuilder;
	
	import flash.data.SQLResult;
	import flash.events.SQLErrorEvent;
	import flash.events.SQLEvent;
	
	/* abstract */ public class StatementBuilder
	{
		protected var sqlBuilder:SqlBuilder = new SqlBuilder();
		
		protected var builder:Builder;
		
		public function StatementBuilder(builder:Builder):void
		{
			this.builder = builder;
			
			writeAttributeStatement();			
			
			sqlBuilder.statement.sqlConnection = builder.sqlConnection;
			sqlBuilder.statement.addEventListener(SQLEvent.RESULT, handleSelect);
			sqlBuilder.statement.parameters[':onePercentage'] = builder.onePercentage;
			
			filterByParent();
			if (builder.configuration.minNodeCost > 0)
			{
				filterByCost();
			}
			if (builder.configuration.hideLibraryFunctions > 0)
			{
				filterByLibraryFunctions();
			}
			
			sqlBuilder.add(SqlBuilder.JOIN, 'tree');
			prepare();
			sqlBuilder.statement.execute(Builder.PREFETCH);
		}
		
		/* abstract */ public function prepare():void
		{
			
		}
		
		/* abstract */ public function writeAttributeStatement():void
		{
			
		}
		
		/* abstract */ protected function get grouped():Boolean
		{
			return false;
		}
		
		private function filterByParent():void
		{
			sqlBuilder.add(SqlBuilder.WHERE, 'left > :left', 'right < :right');
			sqlBuilder.statement.parameters[':left'] = builder.treeItem.left;
			sqlBuilder.statement.parameters[':right'] = builder.treeItem.right;
		}
		
		private function filterByCost():void
		{
			if (grouped)
			{
				sqlBuilder.add(SqlBuilder.HAVING, 'max(inclusiveTime) >= :cost');
			}
			else
			{
				sqlBuilder.add(SqlBuilder.WHERE, 'inclusiveTime >= :cost');
			}
			sqlBuilder.statement.parameters[':cost'] = builder.configuration.minNodeCost * builder.onePercentage;
		}
		
		private function filterByLibraryFunctions():void
		{
			if (grouped)
			{
				sqlBuilder.add(SqlBuilder.HAVING, 'max(fileName) != 0');
			}
			else
			{
				sqlBuilder.add(SqlBuilder.WHERE, 'fileName != 0');
			}
		}
		
		/* abstract */ protected function handleSelect(event:SQLEvent):void
		{
			
		}
		
		protected function next(sqlResult:SQLResult):void
		{
			if (sqlResult.complete)
			{
				builder.checkComplete();
			}
			else
			{				
				sqlBuilder.statement.next(Builder.PREFETCH);
			}
		}
		
		public function cancel():void
		{
			if (sqlBuilder.statement.executing)
			{
				var sqlErrorHandler:Function = function (event:SQLErrorEvent):void { event.target.removeEventListener(SQLErrorEvent.ERROR, sqlErrorHandler); };
				sqlBuilder.statement.addEventListener(SQLErrorEvent.ERROR, sqlErrorHandler, false, 0, false);
				sqlBuilder.statement.cancel();
			}
		}
	}
}