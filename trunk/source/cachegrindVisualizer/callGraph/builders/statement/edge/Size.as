package cachegrindVisualizer.callGraph.builders.statement.edge
{	
	public class Size
	{
		private static const PERCENTAGE_IN_EDGE_LINE_WIDTH:Number = 0.2;
		private static const ARROW_SIZE_COEFFICIENT:Number = 1.5;
		
		private static const MIN_PERCENTAGE:Number = 5;
		private static const MAX_PERCENTAGE:Number = 40;
		
		private static const MIN_PERCENTAGE_FALLBACK_LINE_WIDTH:Number = 1;
		private static const MAX_PERCENTAGE_FALLBACK_LINE_WIDTH:Number = 8;
		
		public function edge(edge:Edge):String
		{
			return build(edge.sizeBase);
		}
		
		protected function build(percentage:Number):String
		{	
			var width:Number;		
			if (percentage < MIN_PERCENTAGE)
			{
				return '';
			}
			else if (percentage < MAX_PERCENTAGE)
			{
				width = percentage * PERCENTAGE_IN_EDGE_LINE_WIDTH;				
			}
			else
			{
				width = MAX_PERCENTAGE_FALLBACK_LINE_WIDTH;
			}
			return 'style="setlinewidth(' + width.toFixed(2) + ')" arrowsize=' + (width / ARROW_SIZE_COEFFICIENT).toFixed(2);
		}
	}
}