package cachegrindVisualizer.callGraph.builders.statement.edge
{	
	public class Size
	{	
		private static const MIN_PERCENTAGE:Number = 0.05;
		private static const MAX_PERCENTAGE:Number = 100;
		
		private static const MIN_LINE_WIDTH:Number = 1;
		private static const MAX_LINE_WIDTH:Number = 8;
				
		private static const TANGENT:Number = (MAX_LINE_WIDTH - MIN_LINE_WIDTH) / (MAX_PERCENTAGE - MIN_PERCENTAGE);
		
		private static const ARROW_SIZE_COEFFICIENT:Number = 1.5;
		
		public function edge(edge:Edge):String
		{
			return build(edge.sizeBase);
		}
		
		protected function build(percentage:Number):String
		{
			if (percentage < MIN_PERCENTAGE)
			{
				return '';
			}
			else
			{
				var width:Number = MIN_LINE_WIDTH + TANGENT * (percentage - MIN_PERCENTAGE);
				return 'style="setlinewidth(' + width.toFixed(2) + ')" arrowsize=' + (width / ARROW_SIZE_COEFFICIENT).toFixed(2);
			}
		}
	}
}