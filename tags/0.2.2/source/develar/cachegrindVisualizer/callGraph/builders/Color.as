package develar.cachegrindVisualizer.callGraph.builders
{
	import develar.cachegrindVisualizer.callGraph.Node;
	import develar.cachegrindVisualizer.Item;
	
	public class Color
	{	
		protected static const MIN_HUE:Number = 0.6;
		protected static const MIN_SATURATION:Number = 0.1;
		protected static const MAX_VALUE:Number = 1;
		
		protected static const EDGE_HUE_COEFFICIENT:Number = 0.05;
		protected static const EDGE_SATURATION_COEFFICIENT:Number = 0.3;
			
		public function node(node:Node):String
		{				
			return build(node.percentage);
		}
		
		public function edge(item:Item):String
		{				
			return build(item.percentage, EDGE_HUE_COEFFICIENT, EDGE_SATURATION_COEFFICIENT);
		}
		
		protected function build(percentage:Number, hueCoefficient:Number = 0, saturationCoefficient:Number = 0):String
		{
			percentage = percentage / 100;
			
			var hue:Number = MIN_HUE + hueCoefficient + percentage;
			if (hue > MAX_VALUE)
			{
				hue = MAX_VALUE;
			}
			
			var saturation:Number = MIN_SATURATION + saturationCoefficient + percentage;
			if (saturation > MAX_VALUE)
			{
				saturation = MAX_VALUE;
			}
			
			return hue + ' ' + saturation + ' ' + MAX_VALUE;
		}
	}
}