package cachegrindVisualizer.callGraph.builders.edge
{
	import cachegrindVisualizer.callGraph.builders.Builder;
	import cachegrindVisualizer.callGraph.builders.Color;
	import cachegrindVisualizer.callGraph.builders.Grouper;
	import cachegrindVisualizer.callGraph.builders.StatementBuilder;
	
	import develar.data.SqlBuilder;
	
	import flash.data.SQLResult;
	import flash.events.SQLEvent;
	
	public class EdgeBuilder extends StatementBuilder
	{		
		protected var previousId:uint;
		protected var previousLevel:uint;
		protected var parentsIds:Object = new Object();
		
		protected var size:Size = new Size();
		
		public function EdgeBuilder(builder:Builder)
		{
			super(builder);
			sqlBuilder.statement.itemClass = Edge;		
		}
		
		override public function writeAttributeStatement():void
		{
			builder.fileStream.writeUTFBytes('edge [fontsize=10 fontname="' + Builder.FONT + '"');
			if (!builder.configuration.blackAndWhite)
			{
				builder.fileStream.writeUTFBytes(' color="' + Color.EDGE_MIN_HUE + ' ' + Color.EDGE_MIN_SATURATION + ' ' + Color.MAX_VALUE + '"');
			}	
			builder.fileStream.writeUTFBytes(']\n');
			
			/**/
			builder.fileStream.writeUTFBytes('node [shape=box fontsize=12 fontname="' + Builder.FONT + '"');
			if (!builder.configuration.blackAndWhite)
			{
				builder.fileStream.writeUTFBytes(' color="' + Color.MIN_HUE + ' ' + Color.MIN_SATURATION + ' ' + Color.MAX_VALUE + '" style=filled');
			}	
			builder.fileStream.writeUTFBytes(']\n');
			/**/
		}
		
		/**
		 * percentage требуется в label.edge для расчета headlabel (поэтому он не зависит от label.needPercentage)
		 */
		override public function prepare():void
		{			
			sqlBuilder.add(SqlBuilder.FIELD, 'name', 'level');
			sqlBuilder.add(SqlBuilder.FIELD, 'time', 'inclusiveTime');			
			if (builder.label.needPercentage)
			{
				sqlBuilder.add(SqlBuilder.FIELD, 'time / :onePercentage as percentage');
				sqlBuilder.add(SqlBuilder.FIELD, 'inclusiveTime / :onePercentage as inclusivePercentage');
			}
			
			if (builder.configuration.grouping == Grouper.FUNCTIONS)
			{
				sqlBuilder.add(SqlBuilder.FIELD, 'name as id');
				if (!builder.label.needPercentage)
				{
					sqlBuilder.add(SqlBuilder.FIELD, 'time / :onePercentage as percentage');
				}
			}
			else if (builder.configuration.grouping == Grouper.NO)
			{
				sqlBuilder.add(SqlBuilder.FIELD, 'abs(left) as id');
				if (!builder.label.needPercentage)
				{
					sqlBuilder.add(SqlBuilder.FIELD, 'inclusiveTime / :onePercentage as inclusivePercentage');
				}
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
				if (builder.configuration.grouping == Grouper.FUNCTIONS)
				{
					builder.nodesNames[edge.name] = null;
				}
				
				if (edge.level > previousLevel)
				{
					parentsIds[edge.level] = previousId;
				}
				
				if (builder.configuration.grouping == Grouper.FUNCTIONS)
				{
					edge.sizeBase = edge.percentage;
				}
				else // Grouper.NO
				{
					edge.sizeBase = edge.inclusivePercentage;
				}					
				
				edges += getParentId(edge) + ' -> ' + edge.id + ' [' + build(edge) + ']\n';
				
				previousLevel = edge.level;
				previousId = edge.id;
			}
			
			builder.fileStream.writeUTFBytes(edges);
			next(sqlResult);
		}	
		
		protected function getParentId(edge:Edge):uint
		{
			return parentsIds[edge.level];
		}	
		
		private function build(edge:Edge):String
		{
			var result:String = builder.label.edge(edge) + size.edge(edge);
			if (!builder.configuration.blackAndWhite)
			{
				result += builder.color.edge(edge);
			}
			return result;
		}
	}
}