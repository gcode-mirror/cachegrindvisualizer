package cachegrindVisualizer.callGraph.builders
{
	import develar.data.SqlBuilder;
	import develar.utils.StringUtil;
	
	import flash.data.SQLResult;
	import flash.data.SQLStatement;
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
			if (builder.configuration.hideFunctions != null)
			{
				filterByFunctions();
			}
			
			sqlBuilder.add(SqlBuilder.JOIN, 'tree');
			prepare();
			trace(StringUtil.replace(sqlBuilder.statement.text, sqlBuilder.statement.parameters) + '\n');
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
		
		private function filterByFunctions():void
		{
			var names:Array = builder.configuration.hideFunctions.split(/[,\s]+/);
			var namesIds:Array = new Array();
			for (var id:String in builder.names)
			{
				if (names.indexOf(builder.names[id]) != -1)
				{
					namesIds.push(uint(id));
				}
			}
				
			var statement:SQLStatement = new SQLStatement();
			statement.sqlConnection = builder.syncSqlConnection;
			statement.text = 'select left, right from tree where name in (' + namesIds.join(', ') + ')';
			statement.execute();
			var data:Array = statement.getResult().data;				
			var nameFilters:Array = new Array();
			for each (var item:Object in data)
			{					
				if (grouped)
				{										
					nameFilters.push('(left >= ' + item.left + ' and right <= ' + item.right + ')');						
				}
				else
				{
					sqlBuilder.add(SqlBuilder.WHERE, 'not (left >= ' + item.left + ' and right <= ' + item.right + ')');
				}
			}							
			if (grouped)
			{
				sqlBuilder.add(SqlBuilder.FIELD, 'not (' + nameFilters.join(' or ') + ') as function_filter_passed');
				if (this is NodeBuilder)
				{
					//sqlBuilder.add(SqlBuilder.HAVING, '(min(function_filter_passed) != 0 or (count(*) > 1 and max(function_filter_passed) = 1))');
				}
				else
				{					
					sqlBuilder.add(SqlBuilder.HAVING, 'max(function_filter_passed) = 1');
				}
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