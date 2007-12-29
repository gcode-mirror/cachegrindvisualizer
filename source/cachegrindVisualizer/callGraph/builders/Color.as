package cachegrindVisualizer.callGraph.builders
{
	import cachegrindVisualizer.callGraph.builders.statement.edge.Edge;
		
	public class Color
	{
		private static const MAX_PERCENTAGE:Number = 100;
		
		public static const MIN_HUE:Number = 0.6;
		public static const MIN_SATURATION:Number = 0.1;
		public static const MAX_VALUE:Number = 1;
		
		/**
		 * Цвет ребра должен быть более заметен, чем цвет фона узла
		 */
		private static const EDGE_HUE_COEFFICIENT:Number = 0.05;
		private static const EDGE_SATURATION_COEFFICIENT:Number = 0.3;
		public static const EDGE_MIN_HUE:Number = MIN_HUE + EDGE_HUE_COEFFICIENT;
		public static const EDGE_MIN_SATURATION:Number = MIN_SATURATION + EDGE_SATURATION_COEFFICIENT;
		
		private static const HUE_TANGENT:Number = (MAX_VALUE - MIN_HUE) / MAX_PERCENTAGE;
		private static const SATURATION_TANGENT:Number = (MAX_VALUE - MIN_SATURATION) / MAX_PERCENTAGE;
		
		private static const EDGE_HUE_TANGENT:Number = (MAX_VALUE - EDGE_MIN_HUE) / MAX_PERCENTAGE;
		private static const EDGE_SATURATION_TANGENT:Number = (MAX_VALUE - EDGE_MIN_SATURATION) / MAX_PERCENTAGE;		
			
		public function node(node:Node):String
		{	
			return build(node.percentage, MIN_HUE, HUE_TANGENT, MIN_SATURATION, SATURATION_TANGENT);
		}
		
		public function edge(edge:Edge):String
		{
			return build(edge.sizeBase, EDGE_MIN_HUE, EDGE_HUE_TANGENT, EDGE_MIN_SATURATION, EDGE_SATURATION_TANGENT);
		}
		
		protected function build(percentage:Number, minHue:Number, hueTangent:Number, minSaturation:Number, saturationTangent:Number):String
		{
			var hue:Number = minHue + (hueTangent * percentage);
			var saturation:Number = minSaturation + (saturationTangent * percentage);
			return ' color="' + hue.toFixed(2) + ' ' + saturation.toFixed(2) + ' ' + MAX_VALUE + '"';
		}
	}
}